lab_host_discovery(){
  assert_lab_subnet || return 0
  command -v nmap >/dev/null 2>&1 || { warn "nmap unavailable."; return; }
  echo "--- Lab Host Discovery: $LAB_SUBNET ---"
  nmap -sn "$LAB_SUBNET" 2>/dev/null || true
  telemetry host_discovery "$LAB_SUBNET"
}
