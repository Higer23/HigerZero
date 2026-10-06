REPORT_JSON="$REPORT_DIR/lab_audit_report.json"
REPORT_HTML="$REPORT_DIR/lab_audit_report.html"
REPORT_CSV="$REPORT_DIR/lab_audit_report.csv"
generate_reports(){
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$REPORT_JSON" <<EOF
{
  "tool":"HigerZero",
  "version":"$VERSION",
  "session_id":"$SESSION_ID",
  "timestamp":"$ts",
  "mode":"safe-lab",
  "active_attack_frames_transmitted":false,
  "lab_subnet":"${LAB_SUBNET:-}",
  "lab_interface":"${LAB_INTERFACE:-}"
}
EOF
  cat > "$REPORT_CSV" <<EOF
metric,value
tool,HigerZero
version,$VERSION
session_id,$SESSION_ID
mode,safe-lab
active_attack_frames_transmitted,false
lab_subnet,${LAB_SUBNET:-}
lab_interface,${LAB_INTERFACE:-}
EOF
  cat > "$REPORT_HTML" <<EOF
<!doctype html><html><head><meta charset="utf-8"><title>HigerZero Audit Report</title></head>
<body><h1>HigerZero Laboratory Audit Report</h1><ul>
<li>Version: $VERSION</li><li>Session: $SESSION_ID</li><li>Mode: safe-lab</li>
<li>Active 802.11 attack frames transmitted: false</li>
<li>Lab subnet: ${LAB_SUBNET:-not configured}</li>
</ul></body></html>
EOF
  info "Reports generated under $REPORT_DIR"
  telemetry reports "json html csv generated"
}
