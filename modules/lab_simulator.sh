run_simulation(){
  echo "--- Attack Behaviour Simulator ---"
  echo "No attack frames will be transmitted."
  echo
  for scenario in DEAUTH BEACON_FLOOD HANDSHAKE_CAPTURE EVIL_TWIN WPS_PIN TRAFFIC_INTERCEPTION; do
    echo "[SIMULATION] $scenario"
    echo "Target: LAB_AP"
    echo "Packets simulated: $SIMULATION_PACKETS"
    echo "Duration: ${SIMULATION_DURATION}s"
    echo "Result: SUCCESS (simulated)"
    echo "No 802.11 attack frames transmitted."
    echo
  done
  telemetry attack_simulation "all scenarios simulated"
}
