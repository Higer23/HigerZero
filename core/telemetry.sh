TELEMETRY_FILE="$LOG_DIR/telemetry.jsonl"
telemetry(){
  local event="$1" detail="${2:-}"
  printf '{"timestamp":"%s","session_id":"%s","event":"%s","detail":"%s"}\n'     "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$event" "$(printf '%s' "$detail" | sed 's/"/\\\"/g')" >> "$TELEMETRY_FILE"
}
