#!/usr/bin/env bash
set -euo pipefail
bash -n higerzero.sh
for f in core/*.sh modules/*.sh gui/*.sh; do bash -n "$f"; done
echo 'parser: PASS'
