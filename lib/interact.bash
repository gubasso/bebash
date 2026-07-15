# shellcheck shell=bash
: 'desc: mode-aware terminal/GUI interaction and feedback'

[[ -n ${__bebash_interact_loaded:-} ]] && return 0
__bebash_interact_loaded=1

__interact_mode=""

interact::mode() {
  if [[ -z $__interact_mode ]]; then
    case "${BEBASH_UI:-auto}" in
    tty) __interact_mode="tty" ;;
    gui) __interact_mode="gui" ;;
    *) if [[ -t 0 ]]; then __interact_mode="tty"; else __interact_mode="gui"; fi ;;
    esac
  fi
  printf '%s\n' "$__interact_mode"
}

interact::is_tty() { [[ $(interact::mode) == tty ]]; }
interact::is_gui() { [[ $(interact::mode) == gui ]]; }

interact::msg() {
  local level="$1"
  shift
  local text="$*"

  if interact::is_gui && command -v notify-send &>/dev/null; then
    local urgency title icon="${BEBASH_UI_ICON:-}"
    title="${BEBASH_UI_LABEL:-${prog_name:-bebash}}"
    case "$level" in
    err) urgency=critical ;;
    info | note) urgency=low ;;
    *) urgency=normal ;;
    esac
    if [[ -n $icon ]]; then
      notify-send -u "$urgency" -i "$icon" "$title" "$text" 2>/dev/null || true
    else
      notify-send -u "$urgency" "$title" "$text" 2>/dev/null || true
    fi
    return 0
  fi

  case "$level" in
  ok) __ui_ok "$text" ;;
  info) __ui_info "$text" ;;
  warn) __ui_warn "$text" ;;
  err) __ui_err "$text" ;;
  note) __ui_hint "$text" ;;
  *) __ui_info "$text" ;;
  esac
}

interact::require_tty() {
  local msg=${1:-"This command requires a terminal"}
  interact::is_tty && return 0
  interact::msg err "$msg"
  return 1
}

interact::require_gui() {
  local msg=${1:-"This command requires a graphical session"}
  interact::is_gui && return 0
  interact::msg err "$msg"
  return 1
}

__interact_rofi() {
  local -n __rofi_out=$1
  shift
  local rc=0 err_file=""

  if ! command -v rofi &>/dev/null; then
    interact::msg err "rofi not found (required for GUI prompts)"
    return 2
  fi
  if ! __is_graphical; then
    interact::msg err "No display available for rofi (needs DISPLAY or WAYLAND_DISPLAY)"
    return 3
  fi
  if ! err_file="$(mktemp 2>/dev/null)"; then
    interact::msg err "Failed to create temp file for rofi stderr capture"
    return 3
  fi

  __rofi_out="$(rofi "$@" 2>"$err_file")" || rc=$?

  local err_content
  err_content="$(head -c 500 "$err_file" 2>/dev/null)" || true
  rm -f "$err_file"

  case $rc in
  0) return 0 ;;
  1) return 1 ;;
  *)
    interact::msg err "rofi failed (rc=$rc): $err_content"
    return 3
    ;;
  esac
}

interact::password() {
  local prompt="$1"
  if interact::is_tty; then
    local pass
    read -r -s -p "$prompt: " pass
    printf '\n' >&2
    [[ -n $pass ]] || return 1
    printf '%s\n' "$pass"
    return 0
  fi

  local result rc=0
  __interact_rofi result -dmenu -password -p "$prompt" </dev/null || rc=$?
  [[ $rc -eq 0 ]] || return "$rc"
  [[ -n $result ]] || return 1
  printf '%s\n' "$result"
}

interact::confirm() {
  local prompt="$1" default_yes=0
  [[ ${2:-} == "--default-yes" ]] && default_yes=1

  if interact::is_tty; then
    local reply hint="[y/N]"
    [[ $default_yes -eq 1 ]] && hint="[Y/n]"
    read -r -p "$prompt $hint " reply
    if [[ $default_yes -eq 1 ]]; then
      [[ ! $reply =~ ^[Nn] ]]
    else
      [[ $reply =~ ^[Yy] ]]
    fi
    return
  fi

  local choice rc=0
  __interact_rofi choice -dmenu -p "$prompt" <<<$'Yes\nNo' || rc=$?
  [[ $rc -eq 0 ]] || return 1
  [[ $choice == "Yes" ]]
}

interact::pick() {
  local title="$1"
  shift
  local -a items=("$@")

  if interact::is_tty; then
    local selected
    if command -v fzf &>/dev/null; then
      local rc=0
      selected="$(printf '%s\n' "${items[@]}" | fzf --prompt="$title: ")" || rc=$?
      case $rc in
      0) ;;
      2)
        interact::msg err "fzf failed"
        return 3
        ;;
      *) return 1 ;;
      esac
    else
      printf '%s\n' "$title:" >&2
      select selected in "${items[@]}"; do
        [[ -n $selected ]] && break
      done
    fi
    [[ -n $selected ]] || return 1
    printf '%s\n' "$selected"
    return 0
  fi

  local result rc=0
  __interact_rofi result -dmenu -p "$title" < <(printf '%s\n' "${items[@]}") || rc=$?
  [[ $rc -eq 0 ]] || return "$rc"
  [[ -n $result ]] || return 1
  printf '%s\n' "$result"
}

interact::pick_multi() {
  local title="$1"
  shift
  local -a items=("$@")

  if interact::is_tty; then
    if ! command -v fzf &>/dev/null; then
      interact::msg err "fzf not found (required for multi-select in a terminal)"
      return 2
    fi
    local selected rc=0
    selected="$(printf '%s\n' "${items[@]}" | fzf --multi \
      --height=~50% --layout=reverse --border \
      --prompt="$title: " \
      --header="TAB: multi-select, ENTER: confirm, ESC: cancel")" || rc=$?
    case $rc in
    0) ;;
    2)
      interact::msg err "fzf failed"
      return 3
      ;;
    *) return 1 ;;
    esac
    printf '%s\n' "$selected"
    return 0
  fi

  local result rc=0
  __interact_rofi result -dmenu -multi-select -p "$title" < <(printf '%s\n' "${items[@]}") || rc=$?
  [[ $rc -eq 0 ]] || return "$rc"
  printf '%s\n' "$result"
}
