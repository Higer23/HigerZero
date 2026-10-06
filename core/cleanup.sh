cleanup_all(){
  [[ -n "${SESSION_ID:-}" ]] && telemetry cleanup "session closed" || true
  # Deliberately do not flush global firewall rules or stop NetworkManager.
  # HigerZero only cleans resources it owns.
}
