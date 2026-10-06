log(){
  local level="$1"; shift
  local msg="$*"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '[%s] [%s] %s\n' "$ts" "$level" "$msg" | tee -a "$LOG_DIR/higerzero.log" >/dev/null
}
info(){ log INFO "$@"; }
warn(){ log WARN "$@"; }
error(){ log ERROR "$@"; }
