#!/usr/bin/env bash
set -euo pipefail
grep -q 'trap - EXIT INT TERM' core/cleanup.sh
grep -q 'Safety lock' core/safety.sh
echo 'cleanup/safety: PASS'
