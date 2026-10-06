emit_metric(){ mkdir -p "${LOG_DIR:-logs}"; printf '{"ts":"%s","event":"%s","value":"%s"}\n' "$(date -Iseconds)" "$1" "$2" >> "${LOG_DIR:-logs}/telemetry.jsonl"; }
