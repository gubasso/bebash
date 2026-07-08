# shellcheck shell=bash
: 'desc: vi-mode readline bindings'

[[ $- == *i* ]] || return 0

bind 'set show-mode-in-prompt on'
bind 'set vi-cmd-mode-string "\1\033[2 q\2[N] "'
bind 'set vi-ins-mode-string "\1\033[6 q\2"'

__readline_edit_buffer_no_exec() {
  local tmp_file editor_rc
  local -a editor_cmd

  tmp_file=$(mktemp "${TMPDIR:-/tmp}/bash-editline.XXXXXX") || return 1
  printf '%s' "$READLINE_LINE" >"$tmp_file"

  if [[ -n "${VISUAL:-}" ]]; then
    # shellcheck disable=SC2206
    editor_cmd=(${VISUAL})
  elif [[ -n "${EDITOR:-}" ]]; then
    # shellcheck disable=SC2206
    editor_cmd=(${EDITOR})
  else
    editor_cmd=(vi)
  fi

  "${editor_cmd[@]}" "$tmp_file"
  editor_rc=$?
  if [[ $editor_rc -eq 0 && -r "$tmp_file" ]]; then
    READLINE_LINE=$(<"$tmp_file")
    READLINE_POINT=${#READLINE_LINE}
  fi
  rm -f -- "$tmp_file"
}

bind -m vi-insert '"\e[A": history-search-backward'
bind -m vi-insert '"\e[B": history-search-forward'
bind -m vi-command '"\e[A": history-search-backward'
bind -m vi-command '"\e[B": history-search-forward'
bind -m vi-insert '"\C-p": history-search-backward'
bind -m vi-insert '"\C-n": history-search-forward'
bind -m vi-command '"\C-p": history-search-backward'
bind -m vi-command '"\C-n": history-search-forward'
bind -m vi-insert '"\e[1;5C": forward-word'
bind -m vi-insert '"\e[1;5D": backward-word'
bind -m vi-command '"\e[1;5C": forward-word'
bind -m vi-command '"\e[1;5D": backward-word'
bind -m vi-insert -x '"\C-g": __readline_edit_buffer_no_exec'
bind -m vi-command -x '"\C-g": __readline_edit_buffer_no_exec'
