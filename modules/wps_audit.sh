#!/usr/bin/env bash
# HZ_NAME=Enterprise WPS Security & Lockout Auditor
# HZ_DESC=Performs non-destructive WPS security posture analysis, lock state detection, and telemetry reporting.
# HZ_VERSION=3.0.1
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab
# HZ_CATEGORY=wireless
# HZ_REQUIRES_ROOT=yes
# HZ_REQUIRES_MONITOR=yes

# ============================================================================
# HigerZero Module: WPS Security & State Auditor
# Non-destructive WPS posture analysis for authorized lab environments.
# ============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. FRAMEWORK FALLBACKS
#    Modül tek başına çalıştırıldığında (bash modules/wps_audit.sh) çökmemesi
#    için tüm HigerZero context değişkenleri ve fonksiyonları için güvenli
#    varsayılanlar tanımlıyoruz.
# ---------------------------------------------------------------------------

# --- Renkler ---
: "${RED:=$'\033[0;31m'}"
: "${GREEN:=$'\033[0;32m'}"
: "${YELLOW:=$'\033[1;33m'}"
: "${BLUE:=$'\033[0;34m'}"
: "${WHITE:=$'\033[1;37m'}"
: "${NC:=$'\033[0m'}"

# --- Dizinler ---
: "${PROJECT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${REPORT_DIR:=${PROJECT_ROOT}/reports}"
: "${CAPTURE_DIR:=${PROJECT_ROOT}/captures}"
: "${LOG_DIR:=${PROJECT_ROOT}/logs}"
mkdir -p "$REPORT_DIR" "$CAPTURE_DIR" "$LOG_DIR"

# --- Lab config ---
: "${LAB_INTERFACE:=}"
: "${DEBUG:=0}"
: "${MODULE_TIMEOUT:=120}"

# --- Logging fonksiyonları (HigerZero framework override eder) ---
if ! declare -F log_info >/dev/null 2>&1; then
    log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
fi
if ! declare -F log_warn >/dev/null 2>&1; then
    log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
fi
if ! declare -F log_error >/dev/null 2>&1; then
    log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fi
if ! declare -F log_debug >/dev/null 2>&1; then
    log_debug() { [[ "${DEBUG}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" || true; }
fi
if ! declare -F print_banner >/dev/null 2>&1; then
    print_banner() { echo -e "${WHITE}=== HigerZero :: WPS Auditor ===${NC}"; }
fi
if ! declare -F log_event >/dev/null 2>&1; then
    log_event() { :; }   # no-op fallback
fi

# --- Session metrics (associative array) güvenli tanım ---
if ! declare -p HIGERZERO_SESSION_METRICS &>/dev/null; then
    declare -gA HIGERZERO_SESSION_METRICS=()
fi

# ---------------------------------------------------------------------------
# 2. CLEANUP HANDLER
#    kill 0 YERİNE sadece kendi child process'lerimizi temizliyoruz.
#    EXIT trap'i burada DEĞİL, module_main içinde set ediliyor.
# ---------------------------------------------------------------------------
WPS_CHILD_PIDS=()

cleanup_wps_ops() {
    local rc=$?
    echo -e "\n${YELLOW}[*] WPS auditor cleanup: terminating child processes...${NC}"

    # Sadece bizim başlattığımız PID'leri öldür
    local pid
    for pid in "${WPS_CHILD_PIDS[@]:-}"; do
        [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done

    # wash süreçlerini sadece bu script'in child'ı olanları öldür
    pkill -P "$$" wash 2>/dev/null || true

    log_event "INFO" "WPS Auditor module cleaned up (rc=$rc)."
    return $rc
}

# ---------------------------------------------------------------------------
# 3. YARDIMCI FONKSİYONLAR
# ---------------------------------------------------------------------------
is_monitor_iface() {
    local iface="$1"
    iwconfig "$iface" 2>/dev/null | grep -q "Mode:Monitor"
}

validate_bssid() {
    local bssid="$1"
    [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]
}

validate_channel() {
    local ch="$1"
    [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= 196 ))
}

json_escape() {
    # Basit JSON string escape (jq yoksa fallback)
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

write_report_json() {
    local out="$1"; shift
    # Geri kalan argümanlar: key=value çiftleri
    if command -v jq >/dev/null 2>&1; then
        local jq_args=()
        local filter="{"
        local first=1
        for kv in "$@"; do
            local k="${kv%%=*}"
            local v="${kv#*=}"
            if (( first )); then first=0; else filter+=","; fi
            filter+="\"$k\":\$k_$k"
            jq_args+=(--arg "k_$k" "$v")
        done
        filter+="}"
        jq -n "${jq_args[@]}" "$filter" > "$out"
    else
        # jq yoksa basit JSON yaz
        {
            printf '{\n'
            local first=1
            for kv in "$@"; do
                local k="${kv%%=*}"
                local v="${kv#*=}"
                (( first )) || printf ',\n'
                first=0
                printf '  "%s": "%s"' "$(json_escape "$k")" "$(json_escape "$v")"
            done
            printf '\n}\n'
        } > "$out"
    fi
}

# ---------------------------------------------------------------------------
# 4. ANA MODÜL
# ---------------------------------------------------------------------------
module_main() {
    # EXIT trap'i burada set etmiyoruz; INT/TERM yeterli.
    trap cleanup_wps_ops INT TERM

    print_banner
    echo -e "${RED}[RED / PURPLE TEAM MODULE]${NC} ${WHITE}Enterprise WPS Security & State Auditor v3.0.1${NC}"
    echo -e "${WHITE}Non-destructive WPS posture checks, lock detection, and JSON telemetry.${NC}"
    log_event "INFO" "Initializing WPS Security & State Auditor v3.0.1."

    # --- Root kontrolü ---
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log_error "Administrative privileges required for wireless diagnostic operations."
        log_event "ERROR" "Non-root execution attempt blocked."
        return 1
    fi

    # --- Bağımlılık kontrolü ---
    local missing=()
    local tool
    for tool in wash iwconfig ip; do
        command -v "$tool" &>/dev/null || missing+=("$tool")
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Install via: sudo apt install reaver wash wireless-tools iproute2"
        log_event "ERROR" "Missing dependencies: ${missing[*]}"
        return 1
    fi

    # --- Interface belirle ---
    local target_iface="${LAB_INTERFACE}"
    if [[ -z "$target_iface" ]]; then
        # Otomatik tespit: monitor modda olan ilk arayüz
        target_iface=$(iwconfig 2>/dev/null | awk '/Mode:Monitor/ {print $1; exit}')
    fi
    if [[ -z "$target_iface" ]]; then
        log_error "No monitor-mode interface found. Set LAB_INTERFACE in config or run airmon-ng."
        log_event "ERROR" "No monitor interface available."
        return 1
    fi

    echo -e "${YELLOW}[*] Active wireless interface:${NC} $target_iface"
    log_debug "Resolved interface: $target_iface"

    # --- Monitor modu doğrulaması ---
    if ! is_monitor_iface "$target_iface"; then
        log_error "Interface '$target_iface' is NOT in monitor mode."
        log_warn  "Run: sudo airmon-ng start ${target_iface}"
        log_event "ERROR" "Interface not in monitor mode: $target_iface"
        return 1
    fi

    # --- Menü ---
    echo ""
    echo "Select WPS Diagnostic Posture Mode:"
    echo "  1) Comprehensive WPS Spectrum Audit (wash -C + JSON report)"
    echo "  2) Targeted AP WPS Lock State & Protocol Check"
    echo "  0) Return / Cancel"
    local wps_choice
    read -r -p "Select diagnostic option (0-2): " wps_choice
    log_event "INFO" "WPS diagnostic mode selected: $wps_choice"

    local timestamp
    timestamp=$(date +%s)
    local report_out="${REPORT_DIR}/wps_audit_report_${timestamp}.json"
    local raw_log="${CAPTURE_DIR}/wps_audit_${timestamp}.log"
    HIGERZERO_SESSION_METRICS["wps_report"]="$report_out"

    case "$wps_choice" in
        1)
            echo -e "${GREEN}[+] Executing comprehensive WPS spectrum audit...${NC}"
            log_event "SUCCESS" "Starting wash spectrum audit."

            # wash çıktısını yakala; başarısız olursa da devam et
            local wash_status=0
            timeout "$MODULE_TIMEOUT" wash -i "$target_iface" -C 2>&1 | tee "$raw_log" || wash_status=$?

            if (( wash_status != 0 )); then
                log_warn "wash exited with status $wash_status (timeout or interrupted)."
            fi

            write_report_json "$report_out" \
                "timestamp=$timestamp" \
                "interface=$target_iface" \
                "audit_type=WPS Spectrum Posture" \
                "status=completed" \
                "raw_log=$raw_log"

            echo -e "${GREEN}[+] Audit report saved:${NC} $report_out"
            log_event "SUCCESS" "WPS JSON report written to $report_out"
            ;;

        2)
            local TARGET_BSSID="${TARGET_BSSID:-}"
            local TARGET_CHANNEL="${TARGET_CHANNEL:-}"

            if [[ -z "$TARGET_BSSID" ]]; then
                read -r -p "Enter Target BSSID (aa:bb:cc:dd:ee:ff): " TARGET_BSSID
            fi
            if ! validate_bssid "$TARGET_BSSID"; then
                log_error "Invalid BSSID format: $TARGET_BSSID"
                log_event "ERROR" "Invalid BSSID: $TARGET_BSSID"
                return 1
            fi

            if [[ -z "$TARGET_CHANNEL" ]]; then
                read -r -p "Enter Target Channel (e.g., 6): " TARGET_CHANNEL
            fi
            if ! validate_channel "$TARGET_CHANNEL"; then
                log_error "Invalid channel: $TARGET_CHANNEL"
                log_event "ERROR" "Invalid channel: $TARGET_CHANNEL"
                return 1
            fi

            echo -e "${YELLOW}[*] Locking $target_iface to channel $TARGET_CHANNEL...${NC}"
            iwconfig "$target_iface" channel "$TARGET_CHANNEL" 2>/dev/null || \
                log_warn "Could not lock channel (may need 'iw dev $target_iface set channel $TARGET_CHANNEL')."

            echo -e "${GREEN}[+] Inspecting WPS state for $TARGET_BSSID...${NC}"
            log_event "SUCCESS" "Inspecting WPS state for BSSID: $TARGET_BSSID"

            # wash zaten channel hopping yapar; -c channel lock değil.
            # Hedef BSSID'yi filtreliyoruz.
            local wash_out
            wash_out=$(timeout "$MODULE_TIMEOUT" wash -i "$target_iface" -C 2>&1 || true)
            echo "$wash_out" | tee "$raw_log"

            local matched
            matched=$(echo "$wash_out" | grep -i "$TARGET_BSSID" || true)
            if [[ -z "$matched" ]]; then
                log_warn "Target BSSID not responding or WPS disabled/hidden."
            else
                echo -e "${GREEN}[MATCH]${NC} $matched"
            fi

            write_report_json "$report_out" \
                "timestamp=$timestamp" \
                "interface=$target_iface" \
                "target_bssid=$TARGET_BSSID" \
                "target_channel=$TARGET_CHANNEL" \
                "audit_type=Targeted WPS State Inspection" \
                "status=analyzed" \
                "raw_log=$raw_log"

            echo -e "${GREEN}[+] Targeted inspection report saved:${NC} $report_out"
            log_event "SUCCESS" "Targeted WPS report written to $report_out"
            ;;

        0|"")
            echo -e "${YELLOW}[WARN] Cancelled by user.${NC}"
            log_event "WARN" "WPS module cancelled by user."
            return 0
            ;;

        *)
            log_warn "Invalid selection. Aborting."
            log_event "WARN" "Invalid option provided in WPS module."
            return 1
            ;;
    esac

    echo -e "${GREEN}[SUCCESS] WPS diagnostic session completed securely.${NC}"
    log_event "SUCCESS" "WPS auditor execution finished safely."
    return 0
}

# ---------------------------------------------------------------------------
# 5. LIFECYCLE HOOKS (opsiyonel, HigerZero loader destekler)
# ---------------------------------------------------------------------------
module_init()    { log_debug "wps_audit: init"; }
module_cleanup() { log_debug "wps_audit: cleanup"; }

export -f module_init module_main module_cleanup 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. DOĞRUDAN ÇALIŞTIRMA
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_main "$@"
fi
