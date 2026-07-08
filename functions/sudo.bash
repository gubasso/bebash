# shellcheck shell=bash
: 'desc: Refresh sudo credentials before running sudo'

__sudo_usage() {
  cat <<'EOF'
usage: sudo [sudo args...]

Refresh sudo credentials, then run sudo.
EOF
}

sudo() {
  case "${1:-}" in
  -h | --help)
    __sudo_usage
    return 0
    ;;
  esac
  command sudo -v || return 1
  command sudo "$@"
}
