# HigerZero Plugins

Plugins are shell modules sourced by an explicit operator action.

Rules:
1. Never transmit deauthentication, beacon-flood, handshake-forcing, WPS attack, or credential-harvesting traffic.
2. Prefer read-only parsing and deterministic simulations.
3. Do not alter global firewall/network-manager state.
4. Return non-zero on validation errors.

Example entry point:

```bash
plugin_name(){ echo "hello"; }
```
