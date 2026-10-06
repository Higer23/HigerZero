# Automatic module discovery. No central registry required.
MODULE_DIR=""
declare -a HZ_MODULE_FILES=()
declare -a HZ_MODULE_NAMES=()
declare -a HZ_MODULE_DESCS=()
load_modules(){ MODULE_DIR="$1"; HZ_MODULE_FILES=(); HZ_MODULE_NAMES=(); HZ_MODULE_DESCS=(); local f n d; while IFS= read -r f; do n="$(grep -m1 '^# HZ_NAME=' "$f"|cut -d= -f2- || true)"; d="$(grep -m1 '^# HZ_DESC=' "$f"|cut -d= -f2- || true)"; [[ -n "$n" ]] || continue; HZ_MODULE_FILES+=("$f"); HZ_MODULE_NAMES+=("$n"); HZ_MODULE_DESCS+=("$d"); done < <(find "$MODULE_DIR" -maxdepth 1 -type f -name '*.sh'|sort); }
run_module(){ local f="${HZ_MODULE_FILES[$1]:-}"; [[ -n "$f" ]] || return 1; unset -f module_main 2>/dev/null || true; source "$f"; declare -F module_main >/dev/null && module_main; unset -f module_main 2>/dev/null || true; }
