# shellcheck shell=bash
: 'desc: Find files with fd, render them with bat, and copy to clipboard'

__fdclip_usage() {
  cat <<'EOF'
usage: fdclip [fd args...]

Find files with fd, render them with bat, and copy the result to the clipboard.
EOF
}

fdclip() {
  case "${1:-}" in
  -h | --help)
    __fdclip_usage
    return 0
    ;;
  esac
  __require_verbose fd bat xclip mktemp || return 1
  local -a files=()
  mapfile -d '' -t files < <(command fd -0 -E .git "$@")
  ((${#files[@]})) || {
    __ui_warn "fdclip: no matches"
    return 1
  }
  local tmp_file
  tmp_file=$(mktemp) || return 1
  command bat --paging=never --decorations=always -- "${files[@]}" >"$tmp_file" || {
    rm -f -- "$tmp_file"
    return 1
  }
  command xclip -selection clipboard <"$tmp_file" || {
    rm -f -- "$tmp_file"
    return 1
  }
  rm -f -- "$tmp_file"
  printf '%s\n' "${files[@]}"
}
