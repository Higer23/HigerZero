wpa_audit(){
  echo "--- WPA/WPS Configuration Audit ---"
  if command -v nmcli >/dev/null 2>&1; then
    nmcli -f BSSID,SSID,SECURITY dev wifi list 2>/dev/null | grep -Ei 'WPA|WEP|WPS|--' || true
  fi
  echo "HigerZero reports configuration indicators only; it never attempts WPS PIN authentication."
  telemetry wpa_audit "completed"
}
