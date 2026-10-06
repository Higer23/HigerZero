#!/usr/bin/env bash
# core/gui_handler.sh - HigerZero GUI Handler
# Manages graphical interface initialization and execution

set -euo pipefail

run_gui() {
    local tui_script="${PROJECT_ROOT:-./}/gui/higerzero_tui.sh"
    
    if [[ ! -f "$tui_script" ]]; then
        echo "Error: TUI script not found at $tui_script"
        return 1
    fi
    
    source "$tui_script" || return 1
    
    if declare -f tui_main &>/dev/null; then
        tui_main "$@"
    elif declare -f main &>/dev/null; then
        main "$@"
    else
        echo "Error: No main function found in TUI script"
        return 1
    fi
}

run_gui_whiptail() {
    while true; do
        local choice
        choice=$(whiptail --title "HigerZero" --menu "Select an option" 15 60 7 \
            1 "WiFi Audit" \
            2 "WPA Audit" \
            3 "Cipher Analysis" \
            4 "Risk Score" \
            5 "View Reports" \
            6 "Exit" \
            3>&1 1>&2 2>&3) || break
        
        case "$choice" in
            1) echo "Running WiFi Audit...;;
            2) echo "Running WPA Audit...;;
            3) echo "Running Cipher Analysis...;;
            4) echo "Running Risk Score...;;
            5) echo "Viewing Reports...;;
            6) break;;
        esac
    done
}

export -f run_gui run_gui_whiptail