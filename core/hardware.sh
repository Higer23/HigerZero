hardware_profile(){
  echo "--- Hardware Profile ---"
  if command -v iw >/dev/null 2>&1; then
    iw dev 2>/dev/null | awk '/Interface /{i=$2} /type /{print i, $2}'
  else
    echo "iw is not installed."
  fi
  if [[ -n "${LAB_INTERFACE:-}" ]]; then
    ip link show "$LAB_INTERFACE" 2>/dev/null || true
    ethtool -i "$LAB_INTERFACE" 2>/dev/null || true
  fi
  telemetry hardware "profiled"
}
