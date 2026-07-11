# shellcheck shell=bash
: 'desc: bebash CLI core parser and dispatcher'

[[ -n "${__bebash_core_loaded:-}" ]] && return 0
__bebash_core_loaded=1

declare -ga __BEBASH_COMMANDS=(doctor list path edit init man version help)
declare -gA __BEBASH_GLOBAL=(
  [json]=0
  [verbosity]=0
  [yes]=0
  [non_interactive]=0
  [color]=auto
)

__bebash_config_dir() {
  printf '%s\n' "${BEBASH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bebash}"
}

__bebash_user_data_dir() {
  printf '%s\n' "${BEBASH_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bebash}"
}

__bebash_state_dir() {
  printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/bebash"
}

__bebash_xdg_data_home() {
  printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

__bebash_manifest_path() {
  printf '%s/install-manifest\n' "$(__bebash_state_dir)"
}

__bebash_completion_path() {
  printf '%s/bash-completion/completions/bebash\n' "$(__bebash_xdg_data_home)"
}

__bebash_man_path() {
  printf '%s/man/man1/bebash.1\n' "$(__bebash_xdg_data_home)"
}

__bebash_log_path() {
  __log_file
}

__bebash_json_string() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\b'/\\b}
  value=${value//$'\f'/\\f}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '"%s"' "$value"
}

__bebash_cmd_symbol() {
  local name=${1//-/_}
  printf '%s' "$name"
}

__bebash_command_known() {
  local needle=${1-} cmd
  for cmd in "${__BEBASH_COMMANDS[@]}"; do
    [[ "$cmd" == "$needle" ]] && return 0
  done
  return 1
}

__bebash_command_desc() {
  local sub=${1-} path line desc
  path="${BEBASH_LIB}/libexec/commands/cmd_${sub}.bash"
  if [[ -r "$path" ]]; then
    while IFS= read -r line; do
      [[ "$line" == ": 'desc: "* ]] || continue
      desc=${line#": 'desc: "}
      desc=${desc%\'}
      printf '%s\n' "$desc"
      return 0
    done <"$path"
  fi
  printf '%s\n' "$sub"
}

__bebash_parse_common() {
  local -a rest=()
  while (($#)); do
    case "$1" in
    --json) __BEBASH_GLOBAL[json]=1 ;;
    -v) __BEBASH_GLOBAL[verbosity]=1 ;;
    -vv) __BEBASH_GLOBAL[verbosity]=2 ;;
    -q | --quiet) __BEBASH_GLOBAL[verbosity]=-1 ;;
    --silent) __BEBASH_GLOBAL[verbosity]=-2 ;;
    --color)
      shift
      (($#)) || bebash::die 2 "--color requires auto, always, or never"
      case "$1" in
      auto | always | never) __BEBASH_GLOBAL[color]=$1 ;;
      *) bebash::die 2 "unknown color mode: $1" ;;
      esac
      ;;
    --color=*)
      case "${1#--color=}" in
      auto | always | never) __BEBASH_GLOBAL[color]=${1#--color=} ;;
      *) bebash::die 2 "unknown color mode: ${1#--color=}" ;;
      esac
      ;;
    -y | --yes) __BEBASH_GLOBAL[yes]=1 ;;
    --non-interactive) __BEBASH_GLOBAL[non_interactive]=1 ;;
    -h | --help)
      rest+=(help)
      shift
      rest+=("$@")
      break
      ;;
    --version)
      rest+=(version)
      shift
      rest+=("$@")
      break
      ;;
    --)
      shift
      rest+=("$@")
      break
      ;;
    -*)
      bebash::die 2 "unknown flag: $1"
      ;;
    *)
      rest+=("$@")
      break
      ;;
    esac
    shift
  done
  __BEBASH_ARGV=("${rest[@]}")
}

__bebash_apply_color() {
  case "${__BEBASH_GLOBAL[color]}" in
  always) export FORCE_COLOR=1 ;;
  never) export NO_COLOR=1 ;;
  auto) ;;
  esac
}

__bebash_ui_err() {
  ((__BEBASH_GLOBAL[verbosity] <= -2)) && return 0
  __ui_err "$@"
}

__bebash_ui_warn() {
  ((__BEBASH_GLOBAL[verbosity] <= -1)) && return 0
  __ui_warn "$@"
}

__bebash_ui_info() {
  ((__BEBASH_GLOBAL[verbosity] >= 1)) || return 0
  __ui_info "$@"
}

__bebash_ui_ok() {
  ((__BEBASH_GLOBAL[verbosity] >= 1)) || return 0
  __ui_ok "$@"
}

bebash::die() {
  local code=${1:-1}
  shift || true
  local msg=${1:-}
  [[ -n "$msg" ]] && __bebash_ui_err "$msg"
  __log_err "${msg:-bebash failed}" "exit=$code"
  return "$code"
}

__bebash_usage() {
  local cmd desc
  printf 'usage: bebash [global flags] <command> [args]\n'
  printf '\n'
  printf 'global flags:\n'
  printf '  -h, --help                 Show usage.\n'
  printf '      --version              Print version.\n'
  printf '  -y, --yes                  Auto-confirm prompts.\n'
  printf '      --non-interactive      Never prompt.\n'
  printf '      --json                 Emit structured stdout where supported.\n'
  printf '  -v, -vv, -q, --quiet       Adjust terminal verbosity.\n'
  printf '      --silent               Suppress terminal UX.\n'
  printf '      --color MODE           auto, always, or never.\n'
  printf '\n'
  printf 'commands:\n'
  for cmd in "${__BEBASH_COMMANDS[@]}"; do
    desc=$(__bebash_command_desc "$cmd")
    printf '  %-10s %s\n' "$cmd" "$desc"
  done
}

bebash::main() {
  __BEBASH_ARGV=()
  __bebash_parse_common "$@"
  __bebash_apply_color

  local sub=${__BEBASH_ARGV[0]:-help}
  if ! __bebash_command_known "$sub"; then
    bebash::die 2 "unknown command: $sub"
    return $?
  fi
  __BEBASH_ARGV=("${__BEBASH_ARGV[@]:1}")

  # shellcheck source=lib/loader.bash
  source "$BEBASH_LIB/lib/loader.bash"
  bebash::loader::dispatch "$sub" "${__BEBASH_ARGV[@]}"
}
