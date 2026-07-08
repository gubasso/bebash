# shellcheck shell=bash
: 'desc: shared project helpers'

[[ -n "${__bebash_project_loaded:-}" ]] && return 0
__bebash_project_loaded=1

__kitty_set_tab_title() {
  [[ -n "${KITTY_WINDOW_ID:-}" ]] || return 0
  command kitten @ set-tab-title "$1" 2>/dev/null || true
}

__project_nvim() {
  local title=${1:?title required} dir=${2:?dir required}
  shift 2
  __kitty_set_tab_title "$title"
  if [[ ! -d "$dir" ]]; then
    __ui_err "directory not found: $dir"
    return 1
  fi
  cd "$dir" || return 1
  command nvim "$@"
}
