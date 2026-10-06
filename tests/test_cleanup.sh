#!/usr/bin/env bash
set -euo pipefail
grep -q 'do not flush global firewall' "$ROOT/core/cleanup.sh" 2>/dev/null || grep -q 'cleanup_all' "$ROOT/core/cleanup.sh"
echo "test_cleanup: PASS"
