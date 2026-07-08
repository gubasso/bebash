# shellcheck shell=bash
: 'desc: Run bebash health checks.'

__bebash_cmd_doctor_usage() {
  printf 'usage: bebash doctor [--json]\n'
}

__bebash_doctor_add() {
  local name=$1 status=$2 detail=$3
  __BEBASH_DOCTOR_CHECKS+=("$name"$'\t'"$status"$'\t'"$detail")
}

__bebash_doctor_required_ok() {
  local check=$1
  case "$check" in
  bash | payload | overlay | path | log-writable) return 0 ;;
  *) return 1 ;;
  esac
}

bebash::cmd::doctor() {
  local json=${__BEBASH_GLOBAL[json]}
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    -h | --help)
      __bebash_cmd_doctor_usage
      return 0
      ;;
    --) shift && break ;;
    -*)
      bebash::die 2 "unknown flag for doctor: $1"
      return $?
      ;;
    *)
      bebash::die 2 "doctor takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($#)) && {
    bebash::die 2 "doctor takes no arguments"
    return $?
  }

  local -a __BEBASH_DOCTOR_CHECKS=()
  local required_failed=0 status detail tool log_file log_dir tmp

  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
    __bebash_doctor_add bash ok "bash ${BASH_VERSION}"
  else
    __bebash_doctor_add bash fail "bash ${BASH_VERSION}; need >=4.4"
    required_failed=1
  fi

  if [[ -r "${BEBASH_LIB}/init.bash" && -d "${BEBASH_LIB}/lib/functions" ]]; then
    __bebash_doctor_add payload ok "$BEBASH_LIB"
  else
    __bebash_doctor_add payload fail "$BEBASH_LIB"
    required_failed=1
  fi

  if [[ -d "$(__bebash_overlay_dir)" ]]; then
    __bebash_doctor_add overlay ok "$(__bebash_overlay_dir)"
  else
    __bebash_doctor_add overlay fail "$(__bebash_overlay_dir)"
    required_failed=1
  fi

  if command -v bebash >/dev/null 2>&1; then
    __bebash_doctor_add path ok "$(command -v bebash)"
  elif [[ -x "${__BEBASH_BIN_DIR:-}/bebash" ]]; then
    __bebash_doctor_add path ok "${__BEBASH_BIN_DIR}/bebash"
  else
    __bebash_doctor_add path fail "bebash not found on PATH"
    required_failed=1
  fi

  log_file=$(__bebash_log_path)
  log_dir=${log_file%/*}
  if mkdir -p -- "$log_dir" 2>/dev/null && tmp=$(mktemp "$log_dir/.doctor.XXXXXX" 2>/dev/null); then
    rm -f -- "$tmp"
    __bebash_doctor_add log-writable ok "$log_file"
  else
    __bebash_doctor_add log-writable fail "$log_file"
    required_failed=1
  fi

  for tool in fzf scdoc git-cliff; do
    if command -v "$tool" >/dev/null 2>&1; then
      __bebash_doctor_add "$tool" ok "$(command -v "$tool")"
    else
      __bebash_doctor_add "$tool" warn "optional tool missing"
    fi
  done

  if ((json)); then
    local first=1 check
    printf '['
    for check in "${__BEBASH_DOCTOR_CHECKS[@]}"; do
      IFS=$'\t' read -r tool status detail <<<"$check"
      ((first)) || printf ','
      first=0
      printf '{"check":%s,"status":%s,"detail":%s}' \
        "$(__bebash_json_string "$tool")" \
        "$(__bebash_json_string "$status")" \
        "$(__bebash_json_string "$detail")"
    done
    printf ']\n'
  else
    local check
    for check in "${__BEBASH_DOCTOR_CHECKS[@]}"; do
      IFS=$'\t' read -r tool status detail <<<"$check"
      printf '%s  %s  %s\n' "$tool" "$status" "$detail"
      if [[ "$status" == warn ]]; then
        __bebash_ui_warn "$tool: $detail"
      elif [[ "$status" == fail ]]; then
        __bebash_ui_err "$tool: $detail"
      fi
    done
  fi

  ((required_failed)) && return 1
  return 0
}
