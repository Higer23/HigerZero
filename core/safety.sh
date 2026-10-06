load_config(){
  local cfg="$1"
  # shellcheck disable=SC1090
  source "$cfg"
}
safety_preflight(){
  if [[ -n "${LAB_INTERFACE:-}" ]] && ! ip link show "$LAB_INTERFACE" >/dev/null 2>&1; then
    warn "Configured LAB_INTERFACE does not exist: $LAB_INTERFACE"
  fi
  if [[ -z "${LAB_SUBNET:-}" ]]; then
    info "LAB_SUBNET is empty; active host discovery remains disabled."
  fi
  telemetry safety_preflight "passed"
}
assert_lab_subnet(){
  [[ -n "${LAB_SUBNET:-}" ]] || { warn "LAB_SUBNET is not configured."; return 1; }
  [[ "$LAB_SUBNET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || {
    error "LAB_SUBNET format rejected: $LAB_SUBNET"; return 1;
  }
}
