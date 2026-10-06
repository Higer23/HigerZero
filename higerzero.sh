#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/core/logger.sh"
source "$ROOT/core/telemetry.sh"
source "$ROOT/core/safety.sh"
source "$ROOT/core/dependencies.sh"
source "$ROOT/core/hardware.sh"
source "$ROOT/core/cleanup.sh"
source "$ROOT/modules/discovery.sh"
source "$ROOT/modules/wifi_audit.sh"
source "$ROOT/modules/channel_analyzer.sh"
source "$ROOT/modules/pmf_audit.sh"
source "$ROOT/modules/wpa_audit.sh"
source "$ROOT/modules/host_discovery.sh"
source "$ROOT/modules/lab_simulator.sh"
source "$ROOT/modules/reports.sh"

VERSION="101.0-safe-lab"
WORK_DIR="$ROOT"
REPORT_DIR="$ROOT/reports"
LOG_DIR="$ROOT/logs"
CAPTURE_DIR="$ROOT/captures"
SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"

cleanup_on_exit(){ cleanup_all; }
trap cleanup_on_exit INT TERM EXIT

banner(){
  printf '\n=== HigerZero %s | SAFE LAB EDITION ===\n' "$VERSION"
  printf 'Session: %s\n' "$SESSION_ID"
  printf 'No active 802.11 attack frames are implemented.\n\n'
}

main(){
  mkdir -p "$REPORT_DIR" "$LOG_DIR" "$CAPTURE_DIR"
  load_config "$ROOT/config/config.conf"
  banner
  check_dependencies
  hardware_profile
  safety_preflight
  while true; do
    echo "1) Wi-Fi discovery"
    echo "2) Wi-Fi/WPA security audit"
    echo "3) Channel analysis"
    echo "4) PMF audit"
    echo "5) WPS configuration audit"
    echo "6) Lab host discovery"
    echo "7) Attack simulation"
    echo "8) Generate reports"
    echo "9) Self-test"
    echo "0) Exit"
    read -r -p "Select: " choice
    case "$choice" in
      1) discover_wifi ;;
      2) wifi_security_audit ;;
      3) analyze_channels ;;
      4) pmf_audit ;;
      5) wpa_audit ;;
      6) lab_host_discovery ;;
      7) run_simulation ;;
      8) generate_reports ;;
      9) run_self_tests ;;
      0) exit 0 ;;
      *) echo "Invalid selection." ;;
    esac
  done
}
main "$@"
