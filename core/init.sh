#!/usr/bin/env bash
# core/init.sh - HigerZero Environment Initialization
# Initializes the HigerZero environment with logging, security checks, and dependencies

set -euo pipefail

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# Initialize environment variables
init_environment() {
    log_info "Initializing HigerZero environment..."
    
    # Export global variables
    export PROJECT_ROOT
    export SCRIPT_DIR
    export MODULE_DIR="${PROJECT_ROOT}/modules"
    export CONFIG_DIR="${PROJECT_ROOT}/config"
    export LOG_DIR="${PROJECT_ROOT}/logs"
    export CAPTURE_DIR="${PROJECT_ROOT}/captures"
    export REPORT_DIR="${PROJECT_ROOT}/reports"
    export PLUGIN_DIR="${PROJECT_ROOT}/plugins"
    
    # Create necessary directories
    mkdir -p "$LOG_DIR" "$CAPTURE_DIR" "$REPORT_DIR" "$PLUGIN_DIR"
    
    # Load configuration
    if [[ -f "${CONFIG_DIR}/config.conf" ]]; then
        source "${CONFIG_DIR}/config.conf" || log_warn "Failed to source config.conf"
        log_info "Configuration loaded"
    else
        log_warn "Configuration file not found: ${CONFIG_DIR}/config.conf"
    fi
    
    # Load core modules
    log_debug "Loading core modules..."
    
    if [[ -f "${SCRIPT_DIR}/logger.sh" ]]; then
        source "${SCRIPT_DIR}/logger.sh" || log_warn "Failed to load logger.sh"
    fi
    
    if [[ -f "${SCRIPT_DIR}/module_loader.sh" ]]; then
        source "${SCRIPT_DIR}/module_loader.sh" || log_warn "Failed to load module_loader.sh"
    fi
    
    if [[ -f "${SCRIPT_DIR}/dependencies.sh" ]]; then
        source "${SCRIPT_DIR}/dependencies.sh" || log_warn "Failed to load dependencies.sh"
    fi
    
    if [[ -f "${SCRIPT_DIR}/safety.sh" ]]; then
        source "${SCRIPT_DIR}/safety.sh" || log_warn "Failed to load safety.sh"
    fi
    
    log_info "Environment initialized successfully"
    return 0
}

# Verify dependencies
verify_environment() {
    log_info "Verifying environment..."
    
    local required_tools=("bash" "grep" "sed" "awk" "find" "sort")
    local missing=0
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "Required tool not found: $tool"
            ((missing++))
        fi
    done
    
    if [[ $missing -gt 0 ]]; then
        log_error "$missing required tools are missing"
        return 1
    fi
    
    log_info "Environment verification passed"
    return 0
}

# Cleanup on exit
cleanup_environment() {
    log_info "Cleaning up..."
}

# Set trap for cleanup
trap cleanup_environment EXIT INT TERM

export -f log_info log_warn log_error log_debug
export -f init_environment verify_environment cleanup_environment