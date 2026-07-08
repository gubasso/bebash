# shellcheck shell=bash
: 'desc: generic updater framework'

[[ -n "${__bebash_updater_loaded:-}" ]] && return 0
__bebash_updater_loaded=1

__up_require_os() {
  (($# >= 3)) || {
    __ui_err "__up_require_os: expected CMD LABEL PATTERN..."
    return 2
  }
  local cmd_name=$1 label=$2 os_release=${__UP_OS_RELEASE:-/etc/os-release} pattern
  shift 2
  [[ -f "$os_release" ]] || {
    __ui_err "$cmd_name requires $label"
    return 1
  }
  for pattern in "$@"; do
    command grep -qE -- "$pattern" "$os_release" && return 0
  done
  __ui_err "$cmd_name requires $label"
  return 1
}

__up_init() {
  __require_verbose sudo || return 1
  command sudo -v || return 1
  declare -g __up_in_progress=1 __up_abort=0
  declare -ga __up_succeeded=() __up_failed=() __up_skipped=() __up_needs_update=()
  declare -gA __up_skip_hints=()
}

__up_teardown() {
  local joined
  __ui_head "Update Summary"
  if ((${#__up_succeeded[@]})); then
    joined=$(printf '%s, ' "${__up_succeeded[@]}")
    __ui_status ok "Succeeded: ${joined%, }"
  fi
  if ((${#__up_failed[@]})); then
    joined=$(printf '%s, ' "${__up_failed[@]}")
    __ui_status error "Failed: ${joined%, }"
  fi
  unset __up_in_progress __up_abort __up_succeeded __up_failed __up_skipped __up_needs_update __up_skip_hints
}

__up_run_required_step() {
  (($# == 3)) || {
    __ui_err "__up_run_required_step: expected LABEL CHECK_CMD UPDATE_CMD"
    return 2
  }
  local label=$1 check_cmd=$2 update_cmd=$3
  command -v "$check_cmd" >/dev/null 2>&1 || {
    __ui_err "$label is required but not installed"
    __up_failed+=("$label")
    __up_abort=1
    return 0
  }
  if eval "$update_cmd"; then
    __up_succeeded+=("$label")
  else
    __up_failed+=("$label")
    __up_abort=1
  fi
}

__up_run_optional_step() {
  (($# >= 3 && $# <= 4)) || {
    __ui_err "__up_run_optional_step: expected LABEL CHECK_CMD UPDATE_CMD [HINT]"
    return 2
  }
  local label=$1 check_cmd=$2 update_cmd=$3 hint=${4:-}
  if ! command -v "$check_cmd" >/dev/null 2>&1; then
    __up_skipped+=("$label")
    [[ -n "$hint" ]] && __up_skip_hints["$label"]=$hint
    return 0
  fi
  if eval "$update_cmd"; then
    __up_succeeded+=("$label")
  else
    __up_failed+=("$label")
  fi
}

__up_wait_zypp_lock() {
  local timeout=${1:-60} elapsed=0
  while command fuser /var/run/zypp.pid >/dev/null 2>&1; do
    ((elapsed >= timeout)) && return 1
    sleep 1
    ((elapsed++))
  done
}

__up_check_upstream() {
  (($# == 3)) || {
    __ui_err "__up_check_upstream: expected LABEL LOCAL_CMD REMOTE_CMD"
    return 2
  }
  local label=$1 local_cmd=$2 remote_cmd=$3 local_v remote_v
  local_v=$(eval "$local_cmd") || return 1
  remote_v=$(eval "$remote_cmd") || return 1
  [[ "$local_v" == "$remote_v" ]] || __up_needs_update+=("$label")
}
