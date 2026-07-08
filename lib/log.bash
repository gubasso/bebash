# shellcheck shell=bash
: 'desc: machine-readable structured logging'

[[ -n "${__bebash_log_loaded:-}" ]] && return 0
__bebash_log_loaded=1

declare -gA __LOG_LEVELS=([error]=40 [warn]=30 [info]=20 [debug]=10)

__log_file() {
  if [[ -n "${BEBASH_LOG_FILE:-}" ]]; then
    printf '%s\n' "$BEBASH_LOG_FILE"
  else
    printf '%s/bebash/bebash.log\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
  fi
}

__log_escape() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

__log() {
  local saved_status=$?
  local level=${1:-info}
  shift || true
  local msg=${1:-}
  (($#)) && shift

  local threshold=${BEBASH_LOG_LEVEL:-warn}
  local lvl_num=${__LOG_LEVELS[$level]:-20}
  local threshold_num=${__LOG_LEVELS[$threshold]:-30}
  ((lvl_num < threshold_num)) && return "$saved_status"

  local ts
  ts=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')

  local record
  printf -v record 'ts=%s level=%s msg="%s"' "$ts" "$level" "$(__log_escape "$msg")"
  (($#)) && record+=" $*"

  local file dir
  file=$(__log_file)
  dir=${file%/*}
  if [[ -n "$dir" ]]; then
    mkdir -p -- "$dir" 2>/dev/null || true
  fi
  printf '%s\n' "$record" >>"$file" 2>/dev/null || true
  [[ -n "${BEBASH_LOG_STDERR:-}" ]] && printf '%s\n' "$record" >&2
  return "$saved_status"
}

__log_err() { __log error "$@"; }
__log_warn() { __log warn "$@"; }
__log_info() { __log info "$@"; }
__log_debug() { __log debug "$@"; }
