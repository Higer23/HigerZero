#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash -n "$ROOT/higerzero.sh"
for f in "$ROOT"/core/*.sh "$ROOT"/modules/*.sh; do bash -n "$f"; done
echo "test_parser: PASS"
