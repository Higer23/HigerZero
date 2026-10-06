wifi_security_audit(){
  echo "--- Wi-Fi Security Configuration Audit ---"
  local data
  data="$(nmcli -f BSSID,SSID,CHAN,SIGNAL,SECURITY dev wifi list 2>/dev/null || true)"
  printf '%s\n' "$data"
  if grep -qE 'WEP|WPA1|--' <<<"$data"; then warn "Potentially weak/open security configuration detected."; fi
  if grep -q 'WPA3' <<<"$data"; then info "WPA3-capable network(s) observed."; fi
  telemetry wifi_audit "completed"
}
