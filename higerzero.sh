#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT/core/logger.sh"
source "$ROOT/core/telemetry.sh"
source "$ROOT/core/safety.sh"
source "$ROOT/core/dependencies.sh"
source "$ROOT/core/cleanup.sh"
source "$ROOT/core/module_loader.sh"
source "$ROOT/gui/higerzero_tui.sh"
init_environment
load_modules "$ROOT/modules"
trap graceful_shutdown INT TERM EXIT
if [[ "${1:-}" == "--cli" ]]; then run_cli; else run_gui; fi
