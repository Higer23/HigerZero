#!/usr/bin/env bash
# HZ_NAME=Network Packet Sniffer
# HZ_DESC=Capture and analyze wireless network packets in real-time
# HZ_VERSION=1.5.0
# HZ_AUTHOR=HigerZero Community

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly CAPTURE_DIR="${PROJECT_ROOT}/captures"
readonly LOG_DIR="${PROJECT_ROOT}/logs"

mkdir -p "$CAPTURE_DIR" "$LOG_DIR"

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

check_tcpdump() {
    if ! command -v tcpdump &>/dev/null; then
        log_error "tcpdump not found. Install: sudo apt install tcpdump"
        return 1
    fi
    log_success "tcpdump found"
    return 0
}

module_main() {
    log_info "=========================================="
    log_info "Network Packet Sniffer v1.5.0"
    log_info "=========================================="
    
    if ! check_tcpdump; then
        return 1
    fi
    
    local interface="${1:-wlan0}"
    local duration="${2:-60}"
    local pcap_file="${CAPTURE_DIR}/capture_$(date +%s).pcap"
    
    log_info "Capturing packets on $interface for ${duration}s"
    log_info "Output: $pcap_file"
    
    if sudo timeout "$duration" tcpdump -i "$interface" -w "$pcap_file" 2>/dev/null; then
        log_success "Packet capture completed"
        log_info "Captured: $(du -h "$pcap_file" | cut -f1)"
        return 0
    else
        log_error "Packet capture failed"
        return 1
    fi
}

trap 'log_info "Interrupted"' INT TERM

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"