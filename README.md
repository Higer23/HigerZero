# HigerZero

Modular wireless security assessment and laboratory simulation framework.

> **Safety:** HigerZero intentionally does not transmit deauthentication, beacon-flood, handshake-forcing, WPS PIN attack, Evil-Twin credential harvesting, or traffic-interception frames. The project focuses on passive assessment, owned-lab host discovery, deterministic attack simulation, telemetry, and reporting.

## Quick start

```bash
git clone https://github.com/Higer23/HigerZero.git
cd HigerZero
chmod +x higerzero.sh core/*.sh modules/*.sh tests/*.sh
./higerzero.sh
```

Root is **not required** for the default audit/simulation workflow.

## Modules

- Wi-Fi discovery and CSV parsing
- adapter/driver capability profile
- WPA/WPA2/WPA3 and WPS configuration audit
- PMF capability audit
- channel/RSSI analysis
- optional host discovery limited to an explicitly configured lab CIDR
- attack-behaviour simulation without 802.11 attack frames
- JSON/HTML/CSV reporting
- JSON telemetry
- plugin loading
- dependency self-test
- cleanup and safety lock

## Safety model

Set `LAB_INTERFACE` and/or `LAB_BSSID_ALLOWLIST` when using lab-specific features. Host discovery is disabled unless `LAB_SUBNET` is explicitly configured.

Licensed under MIT. Use only on systems and networks you own or are explicitly authorized to assess.
