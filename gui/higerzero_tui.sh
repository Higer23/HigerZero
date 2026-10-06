# Dependency-light ANSI terminal GUI.
hz_header() {
  clear
  printf '\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m\n'
  printf '\033[1;36m║                    HIGERZERO v101                           ║\033[0m\n'
  printf '\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m\n'
  printf ' Session: %s | Safety: PASSIVE/LAB | Modules: %d\n\n' "$HZ_SESSION_ID" "${#HZ_MODULE_NAMES[@]}"
}

run_gui() {
  while true; do
    hz_header
    local i
    if (( ${#HZ_MODULE_NAMES[@]} == 0 )); then
      printf '  No modules found. Add a *.sh file to modules/ and press R.\n'
    else
      for i in "${!HZ_MODULE_NAMES[@]}"; do
        printf '  \033[1;32m%02d\033[0m  %-28s %s\n' "$((i+1))" "${HZ_MODULE_NAMES[$i]}" "${HZ_MODULE_DESCS[$i]}"
      done
    fi
    printf '\n R=reload  S=self-test  H=help  Q=quit\n'
    read -r -p ' Select module: ' c
    case "$c" in
      q|Q) break ;;
      r|R) load_modules "$MODULE_DIR" ;;
      s|S) run_self_test; read -r -p 'Press Enter...' ;;
      h|H) hz_help; read -r -p 'Press Enter...' ;;
      ''|*[!0-9]*) : ;;
      *) if (( c >= 1 && c <= ${#HZ_MODULE_NAMES[@]} )); then
           run_module "$((c-1))"
           read -r -p 'Press Enter...'
         fi ;;
    esac
  done
}

run_cli() {
  local i
  printf 'HigerZero modules (auto-numbered):\n'
  for i in "${!HZ_MODULE_NAMES[@]}"; do
    printf '%02d  %-28s %s\n' "$((i+1))" "${HZ_MODULE_NAMES[$i]}" "${HZ_MODULE_DESCS[$i]}"
  done
}

hz_help() {
  hz_header
  cat <<'EOF'
ADD A MODULE IN 3 STEPS

1. Create a file:
   modules/my_module.sh

2. Put module_main() inside it:
   module_main() {
       echo "Hello from my module"
   }

3. Press R or restart HigerZero.

That's it.

The system automatically:
- discovers *.sh files
- ignores files without module_main()
- reads optional HZ_NAME/HZ_DESC
- sorts modules
- assigns menu numbers
- updates numbering when files are added/removed

No registry or menu edit is required.
EOF
}
