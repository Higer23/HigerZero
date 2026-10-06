# HigerZero

## v101 Safe Lab
Modüler wireless audit, configuration analysis ve laboratory simulation framework.

### GUI
`./higerzero.sh` dependency-light ANSI terminal GUI açar. `--cli` yalnızca modül listesini gösterir.

### Yeni modül ekleme
`modules/my_module.sh` oluşturun:

```bash
# HZ_NAME=My Module
# HZ_DESC=Short description
module_main(){ echo 'Hello from my module'; }
```

Restart sonrası otomatik keşfedilir; merkezi registry düzenlemeniz gerekmez.

### Ek modüller
Risk Score, RF Environment Summary, Configuration Audit, SSID Hygiene, Cipher Audit, Lab Topology, Session Metrics, Plugin Doctor, Self-Test, Report Dashboard ve Attack Simulator.

Proje deauthentication, beacon flooding, handshake forcing, WPS PIN attacks, credential harvesting ve traffic interception gerçekleştirmez.
