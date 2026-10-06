graceful_shutdown(){ trap - EXIT INT TERM; log_event INFO "Session $HZ_SESSION_ID closed"; emit_metric session_end closed 2>/dev/null || true; }
init_environment(){ mkdir -p "${LOG_DIR:-logs}" "${REPORT_DIR:-reports}" "${CAPTURE_DIR:-captures}"; safety_check; check_dependencies||true; log_event INFO "Session $HZ_SESSION_ID initialized"; }
