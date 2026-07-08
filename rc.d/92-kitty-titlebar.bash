# shellcheck shell=bash
: 'desc: kitty titlebar prompt hook'

[[ -n "${KITTY_WINDOW_ID:-}" ]] || return 0
[[ -z "${NVIM:-}" ]] || return 0

__kitty_title_precmd() {
  local last_status=$?
  local p="${PWD/#$HOME/\~}" cwd last rest second branch dirty='' exit_str=''

  cwd=$p
  last=${p##*/}
  rest=${p%/*}
  second=${rest##*/}
  [[ "$p" == */*/* ]] && cwd="$second/$last"

  branch=$(command git symbolic-ref --short HEAD 2>/dev/null) ||
    branch=$(command git rev-parse --short HEAD 2>/dev/null) ||
    branch=''
  if [[ -n "$branch" ]]; then
    command git diff --quiet HEAD -- 2>/dev/null || dirty='*'
  fi
  ((last_status != 0)) && exit_str=$last_status

  command kitten @ set-user-vars \
    KITTY_SHELL_CWD="$cwd" \
    KITTY_SHELL_BRANCH="$branch" \
    KITTY_SHELL_DIRTY="$dirty" \
    KITTY_SHELL_EXIT_CODE="$exit_str" \
    KITTY_NVIM='' \
    >/dev/null 2>&1 || true
  command kitten @ set-window-title --temporary "$cwd" >/dev/null 2>&1 ||
    printf '\033]2;%s\a' "$cwd"
  return "$last_status"
}

if [[ ";${PROMPT_COMMAND:-};" != *";__kitty_title_precmd;"* ]]; then
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="__kitty_title_precmd;${PROMPT_COMMAND}"
  else
    PROMPT_COMMAND='__kitty_title_precmd'
  fi
fi
