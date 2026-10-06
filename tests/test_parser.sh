#!/usr/bin/env bash
set -euo pipefail
bash -n "$ROOT/higerzero.sh"
for f in "$ROOT"/core/*.sh "$ROOT"/modules/*.sh; do bash -n "$f"; done
echo "test_parser: PASS"
