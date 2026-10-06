# HigerZero 🔒

**Modular Bash-based Wireless Security Audit Framework**

HigerZero is a professional-grade, authorized wireless security testing platform designed for security professionals, penetration testers, and network administrators.

![Status](https://img.shields.io/badge/Status-Active%20Development-green?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.0.0-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)
![Language](https://img.shields.io/badge/Language-Bash%205.0%2B-red?style=flat-square)

---

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Module Development](#-module-development)
- [Module API Reference](#-module-api-reference)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Disclaimer](#-legal-disclaimer)

---

## ✨ Features

- **Modular Architecture**: Zero-registry system for easy module management
- **CLI & GUI Modes**: Terminal UI (TUI) and command-line interface
- **16+ Specialized Modules**:
  - WiFi Audit (`wifi_audit.sh`)
  - WPA/WPA2 Analysis (`wpa_audit.sh`)
  - Cipher Suite Analysis (`cipher_audit.sh`)
  - SSID Hygiene Checks (`ssid_hygiene.sh`)
  - Risk Scoring Engine (`risk_score.sh`)
  - Host Discovery (`host_discovery.sh`)
  - And more...

- **Security-First Design**:
  - Passive auditing focus
  - Authorized lab simulation
  - Comprehensive logging
  - Safety checks built-in
  - Telemetry system

- **Professional Output**:
  - Structured logging
  - Report generation
  - Progress tracking
  - Packet capture integration

---

## 🔧 Requirements

### System Requirements
- **OS**: Linux (Debian, Kali, Ubuntu, Fedora)
- **Shell**: Bash 5.0 or higher
- **Kernel**: 4.10+ (for modern wireless stack)

### Required Tools & Packages

```bash
# Wireless tools
aircrack-ng          # WiFi auditing suite
wireless-tools       # iw, iwconfig, iwlist
nmcli                # NetworkManager CLI
wpasupplicant        # WPA authentication

# System utilities
grep, sed, awk       # Text processing
find, sort           # File operations
jq                   # JSON processing (optional but recommended)
tcpdump              # Packet capture

# Optional
whiptail or dialog   # For GUI mode
nmtui                # NetworkManager TUI
```

### Distribution-Specific Installation

#### Debian/Ubuntu
```bash
sudo apt update
sudo apt install -y \
  aircrack-ng \
  wireless-tools \
  network-manager \
  wpasupplicant \
  tcpdump \
  jq \
  whiptail
```

#### Kali Linux
```bash
# Kali comes pre-installed with most tools
sudo apt update
sudo apt install -y \
  wireless-tools \
  network-manager \
  jq \
  whiptail
```

#### Fedora/RHEL
```bash
sudo dnf install -y \
  aircrack-ng \
  wireless-tools \
  NetworkManager \
  wpa_supplicant \
  tcpdump \
  jq \
  newt
```

---

## 📥 Installation

### 1. Clone Repository

```bash
git clone https://github.com/Higer23/HigerZero.git
cd HigerZero
chmod +x higerzero.sh
```

### 2. Verify Installation

```bash
# Check Bash version
bash --version  # Should be 5.0+

# Check required tools
./higerzero.sh validate
```

### 3. Configure Environment

```bash
# Edit configuration
vim config/config.conf

# Or use interactive setup (coming in v1.1)
./higerzero.sh --setup
```

---

## 🚀 Quick Start

### CLI Mode
```bash
# Launch CLI
./higerzero.sh --cli

# List available modules
./higerzero.sh list-modules

# Run specific module
./higerzero.sh run wifi_audit
```

### GUI Mode (Default)
```bash
# Launch GUI (TUI)
./higerzero.sh

# Or explicitly
./higerzero.sh gui
```

### Debug Mode
```bash
./higerzero.sh --debug --cli
```

---

## 🔨 Module Development

### Creating Your First Module

HigerZero uses a **Zero-Registry** system: just drop a shell script into the `modules/` directory and it's automatically discovered!

#### Step 1: Create Module File

```bash
cat > modules/my_security_check.sh << 'EOF'
#!/usr/bin/env bash
# HZ_NAME=My Security Check
# HZ_DESC=Performs a custom security audit
# HZ_VERSION=1.0.0
# HZ_AUTHOR=Your Name

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Main module function (REQUIRED)
module_main() {
    log_info "Starting My Security Check..."
    
    # Dependency check
    if ! command -v iwconfig &>/dev/null; then
        log_error "iwconfig not found. Install: apt install wireless-tools"
        return 1
    fi
    
    # Actual audit logic
    log_info "Scanning wireless interfaces..."
    local interfaces
    interfaces=$(iwconfig 2>/dev/null | grep -oE '^[^ ]+' | head -5)
    
    if [[ -z "$interfaces" ]]; then
        log_warn "No wireless interfaces found"
        return 0
    fi
    
    log_info "Found $(echo "$interfaces" | wc -l) wireless interface(s)"
    while IFS= read -r iface; do
        log_info "  - $iface"
    done <<< "$interfaces"
    
    log_info "Audit complete!"
    return 0
}

# Cleanup on signals
trap 'log_info "Interrupted"; exit 130' INT TERM

# Module footer
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && module_main "$@"
EOF

chmod +x modules/my_security_check.sh
```

#### Step 2: Test Your Module

```bash
# Test module directly
bash modules/my_security_check.sh

# Test via HigerZero
./higerzero.sh run my_security_check

# Test with debug output
./higerzero.sh --debug run my_security_check
```

### Module Best Practices

✅ **DO:**
- Include metadata headers (`HZ_NAME`, `HZ_DESC`, `HZ_VERSION`)
- Implement proper error handling
- Use consistent logging (log_info, log_error, log_warn)
- Check dependencies before using tools
- Return appropriate exit codes (0=success, 1=error)
- Clean up resources (trap handlers)
- Add comments explaining logic

❌ **DON'T:**
- Use `rm -rf` without safeguards
- Require root privileges unless essential
- Ignore error handling
- Create global variables without `readonly`
- Write to unexpected locations
- Mix stdout with logging output

---

## 📚 Module API Reference

### Context Variables (Exported by HigerZero)

```bash
# Core paths
$PROJECT_ROOT      # HigerZero installation directory
$SCRIPT_DIR        # core/ directory
$MODULE_DIR        # modules/ directory
$CONFIG_DIR        # config/ directory
$LOG_DIR           # logs/ output directory
$REPORT_DIR        # reports/ output directory
$CAPTURE_DIR       # captures/ output directory

# Configuration
$LAB_INTERFACE     # Wireless interface for testing
$LAB_MODE          # Interface operating mode
$LAB_SUBNET        # Lab network CIDR
$LOG_LEVEL         # Logging level (debug/info/warn/error)
$PASSIVE_MODE      # Boolean: use passive auditing

# Runtime
$DEBUG             # Boolean: debug mode enabled
$MODULE_TIMEOUT    # Module execution timeout (seconds)
```

### Available Logger Functions

```bash
# From core/logger.sh
log_info "Information message"      # Green [INFO]
log_warn "Warning message"          # Yellow [WARN]
log_error "Error message"           # Red [ERROR]
log_debug "Debug message"           # Blue [DEBUG] (only if DEBUG=1)

# With formatting
log_error "Connection to $host failed"
```

### Module Lifecycle Hooks

```bash
# Initialize
module_init() {
    # Called before module_main
    # Use for setup tasks
}

# Main execution (REQUIRED)
module_main() {
    # Your audit logic here
    return 0  # or 1 on error
}

# Cleanup
module_cleanup() {
    # Called after module_main
    # Use for resource cleanup
}

# Export functions
export -f module_init module_main module_cleanup
```

### Example: Using Context Variables

```bash
module_main() {
    # Access lab configuration
    log_info "Testing interface: $LAB_INTERFACE"
    log_info "Lab subnet: $LAB_SUBNET"
    log_info "Passive mode: $PASSIVE_MODE"
    
    # Write output to reports
    local report="${REPORT_DIR}/scan_$(date +%s).json"
    echo '{"results":[]}' > "$report"
    log_info "Report saved to $report"
    
    # Use timeout if needed
    timeout "$MODULE_TIMEOUT" my_long_running_command || log_error "Timeout"
    
    return 0
}
```

---

## 🛠️ Troubleshooting

### Issue: "bash: ./higerzero.sh: Permission denied"

**Solution:**
```bash
chmod +x higerzero.sh
./higerzero.sh
```

### Issue: "iwconfig: command not found"

**Solution:**
```bash
# Debian/Ubuntu
sudo apt install wireless-tools

# Fedora
sudo dnf install wireless-tools
```

### Issue: "No wireless interfaces found"

**Solutions:**
1. Check hardware:
   ```bash
   iwconfig  # List interfaces
   lspci | grep -i wireless  # Check card
   ```

2. Load driver:
   ```bash
   # Common drivers
   sudo modprobe ath9k
   sudo modprobe b43
   sudo modprobe iwlwifi
   ```

3. Configure LAB_INTERFACE manually:
   ```bash
   # Edit config/config.conf
   LAB_INTERFACE="wlan0"
   ```

### Issue: "Error: test_dependencies.sh not found"

**Solution:**
```bash
# Check tests directory
ls -la tests/

# Run available tests
for test in tests/*.sh; do bash "$test"; done
```

### Issue: Modules not loading

**Debug steps:**
```bash
# Enable debug mode
./higerzero.sh --debug list-modules

# Check module syntax
bash -n modules/wifi_audit.sh  # Check for syntax errors

# Verify module_main exists
grep -l "module_main" modules/*.sh
```

---

## 🤝 Contributing

We welcome contributions! Please:

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/HigerZero.git
   cd HigerZero
   ```

2. **Create feature branch**
   ```bash
   git checkout -b feature/my-new-module
   ```

3. **Follow code standards**
   - Use ShellCheck: `shellcheck -x *.sh`
   - Follow naming: `snake_case` for functions, `UPPER_CASE` for constants
   - Add comments for complex logic
   - Use meaningful commit messages

4. **Test thoroughly**
   ```bash
   bash -n your_module.sh  # Syntax check
   bash your_module.sh      # Runtime test
   ```

5. **Submit pull request**
   - Reference related issues
   - Describe changes clearly
   - Include testing results

### Commit Message Format

Following Conventional Commits:
```
feat(modules): add new cipher_audit module
fix(core): handle empty interface config
docs: expand module development guide
test: add integration tests for module loader
chore: update dependencies list
```

---

## 📄 License

MIT License - See LICENSE file for details

Copyright (c) 2026 Higer23

---

## ⚠️ Legal Disclaimer

**IMPORTANT - READ BEFORE USE**

HigerZero is a **professional security testing tool** designed for **authorized use only**.

### Usage Policy

✅ **Authorized Uses:**
- Security research on your own networks
- Authorized penetration testing with written permission
- Educational purposes in controlled lab environments
- Professional security audits with client approval

❌ **Prohibited Uses:**
- **Unauthorized access** to wireless networks
- Testing networks **without explicit owner permission**
- Violating local laws or regulations
- Circumventing security measures on non-owned systems
- Any malicious or illegal purposes

### Legal Responsibility

**Users assume full responsibility** for:
- Obtaining written authorization before testing
- Complying with applicable laws (CFAA, GDPR, local telecom regulations)
- Securing and protecting captured data
- Ethical use of findings

The HigerZero developers and contributors are **NOT liable** for:
- Unauthorized access or attacks
- Data breaches or privacy violations
- Legal consequences from misuse
- System damage or downtime

### Recommended Practices

1. **Always obtain authorization** before testing any network
2. **Document everything** - keep audit logs and written approvals
3. **Use isolated labs** when possible
4. **Report responsibly** - follow coordinated disclosure practices
5. **Respect privacy** - minimize data collection, securely dispose of captures

---

## 📞 Support & Contact

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Wiki**: Community-contributed documentation

---

**Made with ❤️ by the HigerZero Community**

GitHub: https://github.com/Higer23/HigerZero