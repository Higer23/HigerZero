discover_wifi(){
  echo "--- Wi-Fi Discovery (passive scan) ---"
  command -v nmcli >/dev/null 2>&1 || { warn "nmcli unavailable."; return; }
  nmcli -f IN-USE,BSSID,CHAN,FREQ,SIGNAL,SECURITY,SSID dev wifi list --rescan yes 2>/dev/null ||     nmcli -f IN-USE,BSSID,CHAN,FREQ,SIGNAL,SECURITY,SSID dev wifi list 2>/dev/null || true
  telemetry discovery "completed"
}
