# shellcheck shell=bash
: 'desc: human-facing terminal output helpers'

[[ -n "${__bebash_ui_loaded:-}" ]] && return 0
__bebash_ui_loaded=1

declare -gA __UI_SGR=(
  [error]=31
  [warn]=33
  [info]=36
  [ok]=32
  [head]='1;36'
  [accent]=35
  [muted]=2
  [reset]=0
)

__ui_sgr() {
  local role=$1 out
  printf -v out '\x1b[%sm' "${__UI_SGR[$role]}"
  printf '%s' "$out"
}

__ui_use_color() {
  local fd=${1:-1}
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ -n "${FORCE_COLOR:-}" || -n "${CLICOLOR_FORCE:-}" ]] && return 0
  [[ -t "$fd" ]]
}

__ui_msg() {
  local role=$1 label=$2
  shift 2
  local c='' r=''
  if __ui_use_color 2; then
    c=$(__ui_sgr "$role")
    r=$(__ui_sgr reset)
  fi
  printf '%s%s%s %s\n' "$c" "$label" "$r" "$*" >&2
}

__ui_err() { __ui_msg error "error:" "$@"; }
__ui_warn() { __ui_msg warn "warning:" "$@"; }
__ui_info() { __ui_msg info "info:" "$@"; }
__ui_ok() { __ui_msg ok "✓" "$@"; }
__ui_hint() { __ui_msg muted "↳" "$@"; }

__ui_head() {
  local c='' r=''
  if __ui_use_color 1; then
    c=$(__ui_sgr head)
    r=$(__ui_sgr reset)
  fi
  printf '%s%s%s\n' "$c" "$*" "$r"
}

__ui_status() {
  local role=$1
  shift
  local c='' r=''
  if __ui_use_color 1; then
    c=$(__ui_sgr "$role")
    r=$(__ui_sgr reset)
  fi
  printf '%s%s%s\n' "$c" "$*" "$r"
}

__ui_field() {
  printf '  %-*s  %s\n' "$1" "$2" "$3"
}

__ui_confirm() {
  local question='' assume_yes=0
  while (($#)); do
    case "$1" in
    -y | --yes) assume_yes=1 ;;
    *) question=$1 ;;
    esac
    shift
  done

  ((assume_yes)) && return 0
  if [[ ! -t 0 ]]; then
    return 2
  fi

  local reply=''
  read -r -p "$question [y/N] " reply
  [[ "$reply" == [yY] || "$reply" == [yY][eE][sS] ]]
}
