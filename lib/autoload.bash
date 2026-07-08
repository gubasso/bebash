# shellcheck shell=bash
: 'desc: lazy autoload registry for functions and shared libs'

[[ -n "${__bebash_autoload_loaded:-}" ]] && return 0
__bebash_autoload_loaded=1

declare -gA __BEBASH_REGISTRY=()
declare -gA __BEBASH_DESCRIPTIONS=()

__autoload_register() {
  local kind=${1:?kind required} name=${2:?name required} path=${3:?path required}
  __BEBASH_REGISTRY["$kind:$name"]=$path
  case "$kind" in
  function)
    eval "$(printf '%s() { unset -f %s; source %q || return; %s "$@"; }' \
      "$name" "$name" "$path" "$name")"
    ;;
  lib) ;;
  *)
    __ui_err "autoload: unknown kind: $kind"
    return 2
    ;;
  esac
}

__autoload_scan_dir() {
  local kind=${1:?kind required} dir=${2:?dir required}
  [[ -d "$dir" ]] || return 0

  local path name desc
  for path in "$dir"/*.bash; do
    [[ -e "$path" ]] || continue
    name=${path##*/}
    name=${name%.bash}
    desc=$(sed -n "s/^: 'desc: \\(.*\\)'$/\\1/p" "$path" 2>/dev/null | head -n 1)
    [[ -n "$desc" ]] && __BEBASH_DESCRIPTIONS["$kind:$name"]=$desc
    __autoload_register "$kind" "$name" "$path"
  done
}

__bebash_require_lib() {
  local name=${1:?name required} key path
  key="lib:$name"
  path=${__BEBASH_REGISTRY[$key]:-}
  if [[ -z "$path" ]]; then
    __ui_err "unknown library: $name"
    return 69
  fi
  # shellcheck source=/dev/null
  source "$path"
}
