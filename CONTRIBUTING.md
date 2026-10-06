# Contributing to HigerZero 🔒

First off, thanks for taking the time to contribute! 🌟

This document provides guidelines and instructions for contributing to the HigerZero wireless security audit framework.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Code Style](#code-style)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Module Development](#module-development)

---

## Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to making participation in our project and our community a harassment-free experience for everyone.

### Expected Behavior

- Use welcoming and inclusive language
- Be respectful of differing opinions
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

### Unacceptable Behavior

- Harassment, discrimination, or threatening behavior
- Unwelcome comments about protected characteristics
- Deliberate intimidation or personal attacks
- Publishing private information
- Other conduct clearly inappropriate for a professional setting

### Enforcement

Instances of abusive behavior may be reported to the project maintainers. All complaints will be reviewed and investigated fairly and confidentially.

---

## Getting Started

### Prerequisites

- Bash 5.0 or higher
- Git
- GitHub account
- Linux development environment (Debian, Ubuntu, Kali, Fedora)

### Fork and Clone

1. **Fork the repository** on GitHub:
   - Click the "Fork" button at https://github.com/Higer23/HigerZero

2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/HigerZero.git
   cd HigerZero
   ```

3. **Add upstream remote:**
   ```bash
   git remote add upstream https://github.com/Higer23/HigerZero.git
   ```

4. **Verify remotes:**
   ```bash
   git remote -v
   # origin    https://github.com/YOUR_USERNAME/HigerZero.git (fetch)
   # origin    https://github.com/YOUR_USERNAME/HigerZero.git (push)
   # upstream  https://github.com/Higer23/HigerZero.git (fetch)
   # upstream  https://github.com/Higer23/HigerZero.git (push)
   ```

---

## Development Setup

### 1. Install Dependencies

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install -y \
  aircrack-ng \
  wireless-tools \
  network-manager \
  wpasupplicant \
  tcpdump \
  jq \
  shellcheck
```

**Fedora/RHEL:**
```bash
sudo dnf install -y \
  aircrack-ng \
  wireless-tools \
  NetworkManager \
  wpa_supplicant \
  tcpdump \
  jq \
  ShellCheck
```

### 2. Setup Development Environment

```bash
# Navigate to repository
cd HigerZero

# Make scripts executable
chmod +x higerzero.sh
chmod +x core/*.sh
chmod +x modules/*.sh
chmod +x gui/*.sh
chmod +x tests/*.sh

# Verify setup
./higerzero.sh --version
```

### 3. Create Feature Branch

```bash
# Ensure you're on main and synced
git checkout main
git fetch upstream
git rebase upstream/main

# Create feature branch
# Format: type/description
# Examples: feature/new-module, fix/config-loading, docs/update-readme
git checkout -b feature/my-new-feature
```

---

## Making Changes

### General Guidelines

1. **One feature per branch/PR**
   - Keep changes focused and reviewable
   - Avoid mixing unrelated changes

2. **Sync with upstream**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

3. **Test thoroughly before committing**
   ```bash
   bash -n your_file.sh          # Syntax check
   bash your_file.sh             # Runtime test
   shellcheck -x your_file.sh    # Style check
   ```

4. **Keep commits atomic**
   - Each commit should represent one logical change
   - Should be independently buildable

---

## Code Style

### Bash Conventions

```bash
#!/usr/bin/env bash
# Always use this shebang

set -euo pipefail
# Strict mode: exit on error, undefined vars, pipe failures

# Constants in UPPER_CASE with readonly
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_LEVEL="${LOG_LEVEL:-info}"

# Functions in snake_case
my_function() {
    local var1="$1"  # Local variables lowercase
    local result
    
    # Implementation
    result=$(command_here)
    
    echo "$result"
    return 0
}

# Use double quotes for variables
echo "Value: $var"  # Good
echo 'Value: $var'  # Won't expand

# Use $() instead of backticks
var=$(command)
# NOT: var=`command`

# Use [[ ]] for conditionals
if [[ $# -gt 0 ]]; then  # Good
    echo "Has arguments"
fi
# NOT: if [ $# -gt 0 ]; then

# Error handling
if ! command_that_might_fail; then
    log_error "Command failed"
    return 1
fi
```

### Naming Conventions

- **Functions:** `snake_case` (e.g., `init_environment`, `validate_config`)
- **Variables:** lowercase with underscores (e.g., `config_file`, `interface_name`)
- **Constants:** UPPER_CASE (e.g., `PROJECT_ROOT`, `MODULE_TIMEOUT`)
- **Module files:** snake_case with .sh extension (e.g., `wifi_audit.sh`)

### Comments

```bash
# Single line comments for simple explanations

# Multi-line comments for complex logic
# Use one comment per line
# Avoid obvious comments

# Bad:
count=$((count + 1))  # Add 1 to count

# Good:
# Increment counter for next iteration
count=$((count + 1))
```

### Logging

```bash
# Use consistent logging functions
log_info "Operation successful"
log_warn "This might be a problem"
log_error "Critical failure occurred"
log_debug "Detailed debug information"

# Include relevant context
log_error "Failed to connect to $host on port $port"
```

---

## Testing

### Before Every Commit

```bash
# 1. Syntax check
bash -n modules/my_module.sh

# 2. ShellCheck linting
shellcheck -x modules/my_module.sh

# 3. Run the module independently
bash modules/my_module.sh

# 4. Test via HigerZero
./higerzero.sh run my_module

# 5. With debug output
./higerzero.sh --debug run my_module
```

### Running Test Suite

```bash
# Run all tests
for test in tests/*.sh; do bash "$test"; done

# Run specific test
bash tests/test_module_loader.sh
```

### Writing Tests

```bash
# New test template
#!/usr/bin/env bash
# tests/test_my_feature.sh

set -euo pipefail

echo "Testing my feature..."

# Test 1
if my_function arg1 arg2; then
    echo "✓ Test 1 passed"
else
    echo "✗ Test 1 failed"
    exit 1
fi

# Test 2
if [[ $(my_function) == "expected_output" ]]; then
    echo "✓ Test 2 passed"
else
    echo "✗ Test 2 failed"
    exit 1
fi

echo "All tests passed!"
```

---

## Submitting Changes

### Before Push

1. **Verify your changes**
   ```bash
   git status
   git diff
   ```

2. **Stage files**
   ```bash
   git add modules/my_module.sh
   git add tests/test_my_module.sh
   ```

3. **Check uncommitted changes**
   ```bash
   git diff --cached
   ```

### Making Commits

```bash
# Single file commit
git commit -m "feat(modules): add new cipher_audit module"

# Multiple files with description
git commit -m "fix(core): handle empty interface config

- Added validation for LAB_INTERFACE
- Implemented auto-detection using iwconfig
- Added graceful fallback for missing interfaces"
```

### Pushing Changes

```bash
# Push to your fork
git push origin feature/my-new-feature

# If upstream changed, rebase instead of merge
git fetch upstream
git rebase upstream/main
git push -f origin feature/my-new-feature
```

---

## Commit Message Format

Following [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type

- **feat:** New feature
- **fix:** Bug fix
- **docs:** Documentation changes
- **test:** Test additions or changes
- **chore:** Maintenance, dependencies
- **refactor:** Code refactoring
- **perf:** Performance improvements
- **style:** Code formatting

### Scope

- **modules:** Module-related changes
- **core:** Core framework changes
- **config:** Configuration changes
- **docs:** Documentation
- **test:** Tests
- **ci:** CI/CD pipeline

### Examples

```
feat(modules): add new cipher_audit module

Implement detailed WPA/WPA2 cipher suite analysis
including CCMP, TKIP, and mixed mode detection.

Closes #42

fix(core): handle empty interface config

Validate LAB_INTERFACE configuration and implement
auto-detection using iwconfig if not specified.

docs: expand module development guide

Add API reference section with context variables
and example module template.

test(ci): add GitHub Actions workflow

Automated ShellCheck and syntax validation on PRs.
```

---

## Pull Request Process

### 1. Create Pull Request

1. Go to your fork: https://github.com/YOUR_USERNAME/HigerZero
2. Click "New pull request"
3. Set base repository to `Higer23/HigerZero`, base branch to `main`
4. Set head repository to your fork, compare branch to your feature branch

### 2. Fill PR Template

Use the provided template (`.github/pull_request_template.md`):

```markdown
## Description
Brief description of changes

## Related Issues
Closes #123

## Changes
- Change 1
- Change 2

## Testing
- [ ] Tested locally
- [ ] Syntax check passed
- [ ] All tests pass

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed changes
- [ ] Added necessary tests
- [ ] Updated documentation if needed
```

### 3. Address Review Feedback

1. Make requested changes locally
2. Commit with clear messages
3. Push updates to your branch
4. Respond to comments

### 4. Merge Approval

- Your PR will be reviewed by maintainers
- Requires at least 1 approval
- All CI checks must pass
- Branch must be up to date with main

---

## Module Development

Refer to the [Module Development Guide](README.md#-module-development) in README.md for detailed instructions.

### Quick Checklist

- [ ] Metadata headers (`HZ_NAME`, `HZ_DESC`, `HZ_VERSION`)
- [ ] `module_main()` function implemented
- [ ] Error handling for dependencies
- [ ] Consistent logging (log_info, log_error)
- [ ] Proper exit codes (0=success, 1=error)
- [ ] Cleanup handlers (trap INT TERM EXIT)
- [ ] Passes syntax check: `bash -n module.sh`
- [ ] Independently executable: `bash module.sh`
- [ ] ShellCheck passes: `shellcheck -x module.sh`
- [ ] Tests written: `tests/test_module.sh`
- [ ] Documentation comments added

---

## Getting Help

- **Questions?** Open a discussion on GitHub
- **Found a bug?** Create an issue with details
- **Ideas?** Start a discussion or create a feature request
- **Stuck?** Ask in comments on related issues/PRs

---

## Recognition

Contributors will be:
- Added to CONTRIBUTORS.md file
- Mentioned in release notes
- Recognized in GitHub contributors graph

---

Thank you for contributing to HigerZero! 🉋