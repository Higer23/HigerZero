# HigerZero Module System

## Super easy: drop in a file

You do **not** edit a registry, menu, index, or configuration file.

Just put one Bash file into:

`modules/`

Example:

`modules/my_wifi_check.sh`

```bash
#!/usr/bin/env bash

# Optional. If omitted, HigerZero creates a readable name from the filename.
# HZ_NAME=My WiFi Check
# HZ_DESC=My passive lab check

module_main() {
    echo "My module is running"
}
```

Then start HigerZero again, or press **R** in the GUI.

### Automatic numbering

HigerZero scans `modules/*.sh`, checks that the file contains `module_main()`, sorts the files, and automatically assigns menu numbers:

```
01  Cipher Audit
02  My WiFi Check
03  Risk Score Engine
04  SSID Hygiene
...
```

Add or remove a file and the numbering updates automatically. There is **no central module list** to maintain.

### Even simpler

Only this is required:

```bash
module_main() {
    echo "Hello from my module"
}
```

The filename becomes the module name automatically.

### Rules

- Use one `.sh` file per module.
- Keep module logic inside `module_main()`.
- `HZ_NAME` and `HZ_DESC` are optional.
- Do not modify `core/module_loader.sh` when adding modules.
- The framework is designed for passive auditing and authorized lab simulation.
- Active attack, credential harvesting, and traffic interception modules are not accepted.
