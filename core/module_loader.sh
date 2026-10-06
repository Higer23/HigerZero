# Automatic module discovery for HigerZero.
# Drop any *.sh file into modules/ and it becomes a numbered module automatically.
MODULE_DIR=""
declare -a HZ_MODULE_FILES=()
declare -a HZ_MODULE_NAMES=()
declare -a HZ_MODULE_DESCS=()

load_modules() {
  MODULE_DIR="$1"
  HZ_MODULE_FILES=()
  HZ_MODULE_NAMES=()
  HZ_MODULE_DESCS=()

  local f name desc
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    # A module only needs module_main(). Metadata is optional.
    grep -qE '^[[:space:]]*module_main[[:space:]]*\(' "$f" || continue

    name="$(grep -m1 -E '^#[[:space:]]*HZ_NAME=' "$f" | sed 's/^#[[:space:]]*HZ_NAME=//' | sed 's/[[:space:]]*$//' || true)"
    desc="$(grep -m1 -E '^#[[:space:]]*HZ_DESC=' "$f" | sed 's/^#[[:space:]]*HZ_DESC=//' | sed 's/[[:space:]]*$//' || true)"

    if [[ -z "$name" ]]; then
      name="$(basename "$f" .sh | tr '_-' ' ' | sed 's/\b\([a-z]\)/\u\1/g')"
    fi
    [[ -n "$desc" ]] || desc="Auto-discovered module"

    HZ_MODULE_FILES+=( "$f" )
    HZ_MODULE_NAMES+=( "$name" )
    HZ_MODULE_DESCS+=( "$desc" )
  done < <(find "$MODULE_DIR" -maxdepth 1 -type f -name '*.sh' -print | sort -V)
}

run_module() {
  local index="$1"
  local f="${HZ_MODULE_FILES[$index]:-}"
  [[ -n "$f" ]] || return 1

  unset -f module_main 2>/dev/null || true
  source "$f"
  if declare -F module_main >/dev/null 2>&1; then
    module_main
  else
    printf 'Module error: %s has no module_main()\n' "$f" >&2
    return 1
  fi
  unset -f module_main 2>/dev/null || true
}
