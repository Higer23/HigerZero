# Dependency-light ANSI terminal GUI
hz_header(){ clear; printf '\033[1;36m╔══════════════════════════════════════════════════════════════╗\n║                 HIGERZERO v101 SAFE LAB                   ║\n╚══════════════════════════════════════════════════════════════╝\033[0m\n'; printf ' Session: %s | Safety: PASSIVE/LAB\n\n' "$HZ_SESSION_ID"; }
run_gui(){ while true; do hz_header; local i; for i in "${!HZ_MODULE_NAMES[@]}"; do printf '  \033[1;36m%2d\033[0m %-28s %s\n' "$((i+1))" "${HZ_MODULE_NAMES[$i]}" "${HZ_MODULE_DESCS[$i]}"; done; printf '\n R=reload  S=self-test  H=help  Q=quit\n'; read -r -p ' Select: ' c; case "$c" in q|Q) break;; r|R) load_modules "$MODULE_DIR";; s|S) run_self_test; read -r -p 'Press Enter...' ;;
h|H) hz_help; read -r -p 'Press Enter...' ;;
''|*[!0-9]*) :;; *) ((c>=1&&c<=${#HZ_MODULE_NAMES[@]})) && run_module "$((c-1))"; read -r -p 'Press Enter...';; esac; done; }
run_cli(){ local i; for i in "${!HZ_MODULE_NAMES[@]}"; do printf '%2d %-28s %s\n' "$((i+1))" "${HZ_MODULE_NAMES[$i]}" "${HZ_MODULE_DESCS[$i]}"; done; }
hz_help(){ hz_header; cat <<'EOF'
Create modules/my_module.sh with HZ_NAME, HZ_DESC and module_main(). Restart HigerZero. No registry edit is needed.
EOF
}
