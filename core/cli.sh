#!/usr/bin/env bash
# core/cli.sh - HigerZero Command Line Interface
# Provides command-line argument parsing and CLI mode execution

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

show_usage() {
    cat << 'EOF'
HigerZero - Wireless Security Audit Framework
Usage: ./higerzero.sh [OPTIONS] [COMMAND]

GLOBAL OPTIONS:
  --help, -h              Show this help message
  --version, -v           Show version information
  --debug                 Enable debug mode
  --config FILE           Specify custom configuration file
  --log-level LEVEL       Set logging level (debug, info, warn, error)

COMMANDS:
  gui                     Launch graphical interface (default)
  cli                     Launch command-line interface
  list-modules            List all available modules
  run MODULE              Run a specific module
  test                    Run test suite
  validate                Validate configuration and modules
EOF
}

show_version() {
    echo "HigerZero v1.0.0 (Development)"
    echo "Bash-based Wireless Security Audit Framework"
}

list_modules() {
    local module_dir="${MODULE_DIR:-./modules}"
    echo -e "${BLUE}Available Modules:${NC}"
    
    if [[ ! -d "$module_dir" ]]; then
        echo "No modules directory found"
        return 1
    fi
    
    local count=0
    while IFS= read -r module; do
        if [[ -f "$module" && "$module" == *.sh ]]; then
            local name=$(grep -m1 -E '^#[[:space:]]*HZ_NAME=' "$module" | sed 's/.*HZ_NAME=//' | tr -d ' \"')
            local desc=$(grep -m1 -E '^#[[:space:]]*HZ_DESC=' "$module" | sed 's/.*HZ_DESC=//' | tr -d ' \"')
            local modulename=$(basename "$module" .sh)
            printf "  %-20s : %s\n" "$modulename" "${desc:-$name:-No description}"
            ((count++))
        fi
    done < <(find "$module_dir" -maxdepth 1 -name "*.sh" -type f | sort)
    
    echo ""
    echo "Total modules: $count"
}

run_cli() {
    echo -e "${BLUE}HigerZero CLI Mode${NC}"
    local running=true
    while $running; do
        read -p "hz> " -r command args <<< "${@:+$@}" || true
        
        case "${command:-}" in
            help|h|"?")
                echo "Available commands: list, run, exit"
                ;;
            list|ls)
                list_modules
                ;;
            exit|quit|q)
                running=false
                ;;
            "")
                ;;
            *)
                echo "Unknown command: $command"
                ;;
        esac
    done
}

parse_arguments() {
    local mode="gui"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            --cli)
                mode="cli"
                shift
                ;;
            gui|cli|list-modules|test|validate)
                if [[ "$1" == "cli" ]]; then mode="cli"; fi
                shift
                ;;
            *)
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo "$mode"
}

export -f show_usage show_version list_modules run_cli parse_arguments