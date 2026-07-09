# shellcheck shell=bash
: 'desc: Create a Markdown file from a title'

__md_create_usage() {
  cat <<'EOF'
usage: md-create <title...>

Create a Markdown file named from a slugified title.
EOF
}

md-create() {
  case "${1:-}" in
  -h | --help)
    __md_create_usage
    return 0
    ;;
  esac
  (($#)) || {
    __ui_err "usage: md-create <title...>"
    return 2
  }
  __require_verbose slugify || return 1

  local title=$* slug filename
  slug=$(command slugify "$title") || return 1
  [[ -n "$slug" ]] || {
    __ui_err "md-create: slugify produced an empty filename"
    return 1
  }

  filename="${slug}.md"
  if [[ -e "$filename" ]]; then
    __ui_warn "md-create: file already exists: $filename"
    printf '%s\n' "$filename"
    __log_info "md-create exists" "path=\"$(__log_escape "$filename")\""
    return 0
  fi

  printf '# %s\n\n\n' "$title" >"$filename" || return 1
  printf '%s\n' "$filename"
  __log_info "md-create created" "path=\"$(__log_escape "$filename")\""
}
