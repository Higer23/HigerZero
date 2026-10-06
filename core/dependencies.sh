check_dependencies(){ local b; for b in bash awk grep sed date; do command -v "$b" >/dev/null || return 1; done; }
