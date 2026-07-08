# shellcheck shell=bash
: 'desc: bebash CLI source-on-dispatch loader'

[[ -n "${__bebash_loader_loaded:-}" ]] && return 0
__bebash_loader_loaded=1

bebash::loader::dispatch() {
  local sub=${1-}
  shift || true
  local path="${BEBASH_LIB}/libexec/commands/cmd_${sub}.bash"
  [[ -r "$path" ]] || {
    bebash::die 2 "unknown command: $sub"
    return $?
  }

  # shellcheck source=/dev/null
  source "$path" || {
    bebash::die 70 "failed to load command: $sub"
    return $?
  }

  local fn="bebash::cmd::${sub}"
  if ! declare -F "$fn" >/dev/null 2>&1; then
    bebash::die 70 "command handler missing: $sub"
    return $?
  fi
  "$fn" "$@"
}
