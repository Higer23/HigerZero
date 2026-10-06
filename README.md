# HigerZero

HigerZero is a modular Bash-based wireless security **audit and authorized lab simulation** framework.

## Add a module in seconds

The module system is intentionally zero-registry:

1. Create `modules/my_module.sh`
2. Add `module_main()`
3. Restart HigerZero or press **R**

Example:

```bash
#!/usr/bin/env bash

# HZ_NAME=My Module
# HZ_DESC=My custom passive lab check

module_main() {
    echo "Hello from my module"
}
```

That's all. The framework automatically discovers the file, gives it a menu number, and shows it in the GUI.

### Optional metadata

You can omit both metadata lines:

```bash
module_main() {
    echo "Hello"
}
```

HigerZero will create the module name from the filename.

### Automatic numbering

Modules are sorted from `modules/*.sh` and numbered automatically at startup/reload. You never edit a module registry.

```
01  Cipher Audit
02  My Module
03  Risk Score Engine
04  SSID Hygiene
```

Delete a module file and the menu renumbers itself.

## Run

```bash
chmod +x higerzero.sh
./higerzero.sh
```

CLI:

```bash
./higerzero.sh --cli
```

GUI:
- `1-99` run a module
- `R` reload modules
- `S` self-test
- `H` help
- `Q` quit

## Safety

Modules are intended for passive auditing and authorized lab simulation. Do not use HigerZero to perform unauthorized attacks, collect credentials, intercept traffic, or disrupt networks.
