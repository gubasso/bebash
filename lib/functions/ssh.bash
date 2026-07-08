# shellcheck shell=bash
: 'desc: Kitty-aware ssh wrapper'

__ssh_usage() {
  cat <<'EOF'
usage: ssh [ssh args...]

Run kitten ssh inside Kitty, otherwise run ssh.
EOF
}

ssh() {
  case "${1:-}" in
  -h | --help)
    __ssh_usage
    return 0
    ;;
  esac
  if [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
    command kitten ssh "$@"
  else
    command ssh "$@"
  fi
}
