# shellcheck shell=bash
: 'desc: Show bebash usage.'

__bebash_cmd_help_usage() {
  printf 'usage: bebash help [command]\n'
}

bebash::cmd::help() {
  local sub=${1-}
  if [[ -z "$sub" ]]; then
    __bebash_usage
    return 0
  fi
  shift || true
  (($# == 0)) || {
    bebash::die 2 "help takes at most one command"
    return $?
  }
  __bebash_command_known "$sub" || {
    bebash::die 2 "unknown command: $sub"
    return $?
  }

  local file="${BEBASH_LIB}/libexec/commands/cmd_${sub}.bash" usage_fn
  # shellcheck source=/dev/null
  source "$file"
  usage_fn="__bebash_cmd_$(__bebash_cmd_symbol "$sub")_usage"
  if declare -F "$usage_fn" >/dev/null 2>&1; then
    "$usage_fn"
  else
    printf 'usage: bebash %s [args]\n' "$sub"
  fi
}
