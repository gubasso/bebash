# shellcheck shell=bash
: 'desc: Slugify text and copy it to the clipboard'

__slug_usage() {
  cat <<'EOF'
usage: slug <text...>

Slugify text, print the slug, and copy it to the clipboard.
EOF
}

slug() {
  case "${1:-}" in
  -h | --help)
    __slug_usage
    return 0
    ;;
  esac
  (($#)) || {
    __ui_err "usage: slug <text...>"
    return 2
  }
  __require_verbose slugify xclip || return 1
  local out
  out=$(command slugify "$@") || return 1
  printf '%s\n' "$out"
  printf '%s' "$out" | command xclip -selection clipboard
}
