check_dependencies(){
  local optional=(iw nmcli awk sed grep jq nmap)
  for cmd in "${optional[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then info "dependency: $cmd OK"; else warn "dependency: $cmd missing"; fi
  done
  telemetry dependencies "checked"
}
run_self_tests(){
  local failed=0
  for f in "$ROOT"/tests/test_*.sh; do
    if bash "$f"; then :; else failed=$((failed+1)); fi
  done
  [[ "$failed" -eq 0 ]] && info "Self-test passed." || warn "$failed self-test(s) failed."
}
