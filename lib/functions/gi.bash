# shellcheck shell=bash
: 'desc: Fetch .gitignore templates from gitignore.io'

__gi_usage() {
  cat <<'EOF'
usage: gi <language>

Fetch a .gitignore template from gitignore.io.
EOF
}

gi() {
  case "${1:-}" in
  -h | --help)
    __gi_usage
    return 0
    ;;
  esac
  [[ $# -eq 1 ]] || {
    __ui_err "usage: gi <language>"
    return 2
  }
  __require_verbose curl || return 1
  command curl -fsSL "https://www.toptal.com/developers/gitignore/api/$1"
}
