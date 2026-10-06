analyze_channels(){
  echo "--- Channel Analyzer ---"
  command -v nmcli >/dev/null 2>&1 || { warn "nmcli unavailable."; return; }
  nmcli -t -f CHAN,SIGNAL,SSID dev wifi list 2>/dev/null |
    awk -F: '{count[$1]++; signal[$1]+=$2} END {for(c in count) printf "channel=%s networks=%d avg_signal=%.1f\n",c,count[c],signal[c]/count[c]}' |
    sort -n
  telemetry channel_analysis "completed"
}
