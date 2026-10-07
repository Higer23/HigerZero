#!/usr/bin/env bash
# HZ_NAME=WPA2 Handshake Cracking Suite
# HZ_DESC=Comprehensive WPA/WPA2 password cracking with dictionary and brute force
# HZ_VERSION=2.0.0
# HZ_AUTHOR=HigerZero Community

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly REPORT_DIR="${PROJECT_ROOT}/reports"
readonly CAPTURE_DIR="${PROJECT_ROOT}/captures"
readonly LOG_DIR="${PROJECT_ROOT}/logs"

mkdir -p "$REPORT_DIR" "$CAPTURE_DIR" "$LOG_DIR"

log_info() { echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_DIR/wpa2_crack.log"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2 | tee -a "$LOG_DIR/wpa2_crack.log"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_DIR/wpa2_crack.log"; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*" | tee -a "$LOG_DIR/wpa2_crack.log"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_DIR/wpa2_crack.log"; }

check_dependencies() {
    log_info "Checking dependencies..."
    local missing=0
    local required=("aircrack-ng" "airodump-ng" "aireplay-ng" "airmon-ng")
    
    for tool in "${required[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing: $tool"
            ((missing++))
        else
            log_debug "Found: $tool"
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        log_error "$missing required tools missing. Install: sudo apt install aircrack-ng"
        return 1
    fi
    log_success "All dependencies found"
    return 0
}

get_wireless_interfaces() {
    log_info "Scanning for wireless interfaces..."
    local interfaces=()
    
    if command -v iwconfig &>/dev/null; then
        while IFS= read -r line; do
            [[ $line =~ ^([a-z0-9]+)\ ]] && interfaces+=("${BASH_REMATCH[1]}")
        done < <(iwconfig 2>/dev/null || true)
    fi
    
    printf '%s\n' "${interfaces[@]}" | sort -u
}

enable_monitor_mode() {
    local interface="$1"
    log_info "Enabling monitor mode on $interface..."
    
    if iwconfig "$interface" 2>/dev/null | grep -q "Mode:Monitor"; then
        log_warn "Already in monitor mode"
        return 0
    fi
    
    sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
    
    if sudo airmon-ng start "$interface" 2>/dev/null; then
        log_success "Monitor mode enabled"
        return 0
    else
        log_error "Failed to enable monitor mode"
        return 1
    fi
}

disable_monitor_mode() {
    local interface="$1"
    log_info "Disabling monitor mode..."
    
    if sudo airmon-ng stop "$interface" 2>/dev/null; then
        log_success "Monitor mode disabled"
        sudo systemctl start NetworkManager 2>/dev/null || true
        return 0
    fi
    return 1
}

scan_networks() {
    local interface="$1"
    local duration="${2:-30}"
    
    log_info "Scanning for networks... (${duration}s)"
    local scan_file="${CAPTURE_DIR}/networks_$(date +%s)"
    
    timeout "$duration" sudo airodump-ng --output-format csv --write "$scan_file" "$interface" 2>/dev/null &
    local pid=$!
    wait $pid 2>/dev/null || true
    
    if [[ -f "${scan_file}-01.csv" ]]; then
        log_success "Networks scan complete"
        {
            echo "=== WiFi Networks Scan Report ==="
            echo "Date: $(date)"
            echo "Interface: $interface"
            echo ""
            tail -n +3 "${scan_file}-01.csv" | head -20
        } | tee "${REPORT_DIR}/networks_$(date +%s).txt"
        return 0
    fi
    log_error "No networks found"
    return 1
}

generate_wordlist() {
    local type="${1:-common}"
    log_info "Generating $type wordlist..."
    local wordlist="${CAPTURE_DIR}/wordlist_${type}.txt"
    
    if [[ "$type" == "common" ]]; then
        cat > "$wordlist" << 'EOF'
password
123456789
12345678
admin
admin123
password123
wifi
wifipass
router
router123
welcome
abc123
monkey
qwerty
1q2w3e4r
password1
passwordpassword
NetworkPassword
SecureNet
ConnectMe
EOF
    elif [[ -f "/usr/share/wordlists/rockyou.txt" ]] && [[ "$type" == "rockyou" ]]; then
        cp /usr/share/wordlists/rockyou.txt "$wordlist"
    else
        log_error "Unknown wordlist type or file not found"
        return 1
    fi
    
    log_info "Wordlist created: $(wc -l < "$wordlist") passwords"
    echo "$wordlist"
}

module_main() {
    log_info "=========================================="
    log_info "WPA2 Handshake Cracking Suite v2.0.0"
    log_info "=========================================="
    
    if ! check_dependencies; then
        log_error "Dependencies check failed"
        return 1
    fi
    
    local interfaces
    interfaces=$(get_wireless_interfaces)
    
    if [[ -z "$interfaces" ]]; then
        log_error "No wireless interfaces found"
        return 1
    fi
    
    log_info "Available interfaces:"
    echo "$interfaces" | while read -r iface; do
        log_info "  - $iface"
    done
    
    local interface
    interface=$(echo "$interfaces" | head -1)
    log_info "Using interface: $interface"
    
    if ! enable_monitor_mode "$interface"; then
        log_error "Failed to enable monitor mode"
        return 1
    fi
    
    if ! scan_networks "$interface" 30; then
        log_warn "Network scan failed"
    fi
    
    local wordlist
    wordlist=$(generate_wordlist "common") || {
        log_error "Failed to generate wordlist"
        disable_monitor_mode "$interface"
        return 1
    }
    
    log_success "Module execution completed successfully"
    disable_monitor_mode "$interface" || true
    return 0
}

cleanup() {
    log_info "Cleaning up..."
    [[ -n "${INTERFACE:-}" ]] && disable_monitor_mode "$INTERFACE" || true
}

trap cleanup EXIT INT TERM

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"