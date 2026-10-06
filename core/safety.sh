LAB_MODE=SAFE
HZ_SESSION_ID="HZ-$(date +%Y%m%d-%H%M%S)-$RANDOM"
LAB_SUBNET="${LAB_SUBNET:-}"
safety_check(){ log_event INFO 'Safety lock active: passive/audit mode'; }
