# HZ_NAME=Session Metrics
# HZ_DESC=Telemetry ve oturum metrikleri
module_main(){ echo "Session: $HZ_SESSION_ID"; [[ -f "${LOG_DIR:-logs}/telemetry.jsonl" ]] && wc -l "${LOG_DIR:-logs}/telemetry.jsonl"; }
