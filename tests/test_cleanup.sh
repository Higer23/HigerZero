#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q "do not flush global firewall" "$ROOT/core/cleanup.sh"
echo "test_cleanup: PASS"
