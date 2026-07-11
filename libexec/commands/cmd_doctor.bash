# shellcheck shell=bash
: 'desc: Run bebash verification checks.'

__bebash_cmd_doctor_usage() {
  printf 'usage: bebash doctor [--json] [--logs[=N]] [--no-tools] [--scope all|payload|user]\n'
}

__bebash_doctor_logs() {
  local count=$1 log_file
  log_file=$(__bebash_log_path)
  [[ -r "$log_file" ]] || return 0
  tail -n "$count" "$log_file" 2>/dev/null || return 1
}

__bebash_doctor_json_logs() {
  local count=$1 line first=1
  printf '['
  while IFS= read -r line; do
    ((first)) || printf ','
    first=0
    __bebash_json_string "$line"
  done < <(__bebash_doctor_logs "$count")
  printf ']'
}

bebash::cmd::doctor() {
  local json=${__BEBASH_GLOBAL[json]} logs=0 log_count=40 tools=auto scope=all
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    --logs)
      logs=1
      log_count=40
      ;;
    --logs=*)
      logs=1
      log_count=${1#--logs=}
      [[ "$log_count" =~ ^[0-9]+$ ]] || {
        bebash::die 2 "--logs requires a non-negative integer"
        return $?
      }
      ;;
    --no-tools) tools=never ;;
    --scope)
      shift
      (($#)) || {
        bebash::die 2 "--scope requires all, payload, or user"
        return $?
      }
      scope=$1
      ;;
    --scope=*) scope=${1#--scope=} ;;
    -h | --help)
      __bebash_cmd_doctor_usage
      return 0
      ;;
    --)
      shift
      break
      ;;
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
  (($# == 0)) || {
    bebash::die 2 "doctor takes no arguments"
    return $?
  }
  case "$scope" in
  all | payload | user) ;;
  *)
    bebash::die 2 "--scope requires all, payload, or user"
    return $?
    ;;
  esac

  # shellcheck source=lib/verify.bash
  source "$BEBASH_LIB/lib/verify.bash"
  __BEBASH_VERIFY_RESULTS=()
  __bebash_verify_run_env
  __bebash_verify_run_structural "$scope"
  __bebash_verify_run_tools user "$tools"

  local ok warn fail status log_error='' item_count
  IFS=$'\t' read -r ok warn fail < <(__bebash_verify_summary_counts)
  status=ok
  ((fail == 0)) || status=fail
  item_count=${#__BEBASH_VERIFY_RESULTS[@]}

  if ((json)); then
    printf '{'
    printf '"ok":'
    ((fail == 0)) && printf 'true' || printf 'false'
    printf ',"paths":{"payload":%s,"config":%s,"data":%s,"log":%s}' \
      "$(__bebash_json_string "$BEBASH_LIB")" \
      "$(__bebash_json_string "$(__bebash_config_dir)")" \
      "$(__bebash_json_string "$(__bebash_user_data_dir)")" \
      "$(__bebash_json_string "$(__bebash_log_path)")"
    printf ',"summary":{"ok":%s,"warn":%s,"fail":%s}' "$ok" "$warn" "$fail"
    printf ',"checks":'
    __bebash_verify_results_json
    printf ',"logs":'
    if ((logs)); then
      if ! __bebash_doctor_logs "$log_count" >/dev/null 2>&1; then
        log_error='could not read log file'
      fi
      __bebash_doctor_json_logs "$log_count"
    else
      printf '[]'
    fi
    [[ -z "$log_error" ]] || printf ',"logs_error":%s' "$(__bebash_json_string "$log_error")"
    printf '}\n'
  else
    __ui_head "bebash doctor"
    printf '\n'
    __ui_field 7 payload "$BEBASH_LIB"
    __ui_field 7 config "$(__bebash_config_dir)"
    __ui_field 7 data "$(__bebash_user_data_dir)"
    __ui_field 7 log "$(__bebash_log_path)"
    printf '\n'
    __ui_head summary
    __ui_field 5 ok "$ok"
    __ui_field 5 warn "$warn"
    __ui_field 5 fail "$fail"
    printf '\n'
    __ui_head checks
    __bebash_verify_results_text
    if ((logs)); then
      printf '\n'
      __ui_head logs
      __bebash_doctor_logs "$log_count" || printf '  warning: could not read log file\n'
    fi
  fi

  __log_info "doctor run" "op=doctor status=$status checks=$item_count fail=$fail"
  ((fail == 0)) || return 1
  return 0
}
