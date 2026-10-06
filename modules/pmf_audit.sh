pmf_audit(){
  echo "--- PMF Audit ---"
  echo "PMF is assessed from beacon/management-frame capability data when exposed by the platform."
  if command -v iw >/dev/null 2>&1 && [[ -n "${LAB_INTERFACE:-}" ]]; then
    iw dev "$LAB_INTERFACE" scan 2>/dev/null | grep -Ei 'BSS |RSN:|MFP|PMF' | head -n 120 || true
  else
    echo "Set LAB_INTERFACE and install iw for detailed local scan parsing."
  fi
  telemetry pmf_audit "completed"
}
