# shellcheck shell=bash
: 'desc: bebash artifact convention verifier'

[[ -n "${__bebash_verify_loaded:-}" ]] && return 0
__bebash_verify_loaded=1

__bebash_verify_add() {
  __BEBASH_VERIFY_RESULTS+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$4"$'\t'"$5"$'\t'"${6:-}")
}

__bebash_verify_line() {
  local path=${1-} n=${2-}
  [[ -r "$path" && "$n" =~ ^[0-9]+$ ]] || return 0
  sed -n "${n}p" "$path" 2>/dev/null || true
}

__bebash_verify_public_name() {
  [[ ${1-} =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]
}

__bebash_verify_internal_name() {
  [[ ${1-} =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

__bebash_verify_collapse() {
  local value=${1-}
  value=${value//$'\r'/ }
  value=${value//$'\n'/ | }
  value=${value//$'\t'/ }
  printf '%s' "$value"
}

__bebash_verify_summary_counts() {
  local ok=0 warn=0 fail=0 item severity
  for item in "${__BEBASH_VERIFY_RESULTS[@]:-}"; do
    item=${item//$'\t'/$'\x1f'}
    IFS=$'\x1f' read -r severity _ <<<"$item"
    case "$severity" in
    ok) ok=$((ok + 1)) ;;
    warn) warn=$((warn + 1)) ;;
    fail) fail=$((fail + 1)) ;;
    esac
  done
  printf '%s\t%s\t%s\n' "$ok" "$warn" "$fail"
}

__bebash_verify_results_json() {
  local first=1 item severity code scope path message detail
  printf '['
  for item in "${__BEBASH_VERIFY_RESULTS[@]:-}"; do
    item=${item//$'\t'/$'\x1f'}
    IFS=$'\x1f' read -r severity code scope path message detail <<<"$item"
    ((first)) || printf ','
    first=0
    printf '{"severity":%s,"code":%s,"scope":%s,"path":%s,"message":%s,"detail":%s}' \
      "$(__bebash_json_string "$severity")" \
      "$(__bebash_json_string "$code")" \
      "$(__bebash_json_string "$scope")" \
      "$(__bebash_json_string "$path")" \
      "$(__bebash_json_string "$message")" \
      "$(__bebash_json_string "$detail")"
  done
  printf ']'
}

__bebash_verify_results_text() {
  local item severity code scope path message detail line
  for item in "${__BEBASH_VERIFY_RESULTS[@]:-}"; do
    item=${item//$'\t'/$'\x1f'}
    IFS=$'\x1f' read -r severity code scope path message detail <<<"$item"
    line=$(printf '  %-5s %-8s' "$severity" "$code")
    [[ -n "$path" ]] && line+="  $path"
    line+="  $message"
    [[ -n "$detail" ]] && line+=" ($detail)"
    printf '%s\n' "$line"
  done
}

__bebash_verify_collect() {
  local scope=${1:-all} config data file name
  config=$(__bebash_config_dir)
  data=$(__bebash_user_data_dir)
  if [[ "$scope" == payload || "$scope" == all ]]; then
    for file in "$BEBASH_LIB"/functions/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'function\tpayload\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$BEBASH_LIB"/lib/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'lib\tpayload\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$BEBASH_LIB"/rc.d/*; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'rc\tpayload\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$BEBASH_LIB"/libexec/commands/*; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      name=${name#cmd_}
      printf 'cmd\tpayload\t%s\t%s\0' "$file" "${name%.bash}"
    done
  fi
  if [[ "$scope" == user || "$scope" == all ]]; then
    for file in "$data"/functions/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'function\tuser\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$data"/lib/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'lib\tuser\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$data"/rc.d/*; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'rc\tuser\t%s\t%s\0' "$file" "${name%.bash}"
    done
    for file in "$data"/commands/*; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf 'standalone\tuser\t%s\t%s\0' "$file" "$name"
    done
    [[ -e "$config/config.bash" ]] && printf 'config\tuser\t%s\tconfig\0' "$config/config.bash"
    for file in "$config"/disabled.d/*; do
      [[ -e "$file" || -L "$file" ]] || continue
      name=${file##*/}
      printf 'disabled\tuser\t%s\t%s\0' "$file" "${name%.bash}"
    done
  fi
}

__bebash_verify_check_header() {
  local code_scope=$1 path=$2 first second
  first=$(__bebash_verify_line "$path" 1)
  second=$(__bebash_verify_line "$path" 2)
  [[ "$first" == '# shellcheck shell=bash' ]] || \
    __bebash_verify_add fail SRC001 "$code_scope" "$path" "sourced file must start with shellcheck shell marker"
  [[ "$second" =~ ^:\ \'desc:\ .+\'$ ]] || \
    __bebash_verify_add fail SRC002 "$code_scope" "$path" "sourced file must declare a desc marker on line 2"
}

__bebash_verify_bash_n() {
  local scope=$1 path=$2 output
  output=$(bash -n "$path" 2>&1) || {
    __bebash_verify_add fail SRC004 "$scope" "$path" "bash syntax check failed" "$(__bebash_verify_collapse "$output")"
  }
}

__bebash_verify_function_names() {
  local path=$1
  sed -nE \
    -e 's/^[[:space:]]*function[[:space:]]+([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*(\(\))?[[:space:]]*\{.*/\1/p' \
    -e 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_:.-]*)[[:space:]]*\(\)[[:space:]]*\{.*/\1/p' \
    "$path" 2>/dev/null
}

__bebash_verify_public_defs() {
  local path=$1
  __bebash_verify_function_names "$path" | while IFS= read -r fn; do
    [[ "$fn" == __* || "$fn" == *::* ]] && continue
    printf '%s\n' "$fn"
  done
}

__bebash_verify_check_function() {
  local scope=$1 path=$2 expected=$3 defs count first
  __bebash_verify_check_header "$scope" "$path"
  [[ "$path" == *.bash ]] || __bebash_verify_add fail SRC003 "$scope" "$path" "sourced file must end in .bash"
  __bebash_verify_bash_n "$scope" "$path"
  __bebash_verify_public_name "$expected" || \
    __bebash_verify_add fail FUNC001 "$scope" "$path" "function filename must be a valid public name"
  if ! grep -Eq "^[[:space:]]*(function[[:space:]]+)?${expected}([[:space:]]*\\(\\))?[[:space:]]*\\{" "$path"; then
    __bebash_verify_add fail FUNC002 "$scope" "$path" "function file must define public function \"$expected\""
  fi
  defs=$(__bebash_verify_public_defs "$path")
  count=$(printf '%s\n' "$defs" | sed '/^$/d' | wc -l)
  first=$(printf '%s\n' "$defs" | sed '/^$/d' | sed -n '1p')
  [[ "$count" == 1 && "$first" == "$expected" ]] || \
    __bebash_verify_add fail FUNC003 "$scope" "$path" "function file must define exactly one public function matching its filename"
}

__bebash_verify_check_lib() {
  local scope=$1 path=$2 expected=$3 defs
  __bebash_verify_check_header "$scope" "$path"
  [[ "$path" == *.bash ]] || __bebash_verify_add fail SRC003 "$scope" "$path" "sourced file must end in .bash"
  __bebash_verify_bash_n "$scope" "$path"
  __bebash_verify_internal_name "$expected" || \
    __bebash_verify_add fail LIB001 "$scope" "$path" "lib filename must be a valid internal name"
  grep -q "__bebash_${expected}_loaded" "$path" || \
    __bebash_verify_add fail LIB002 "$scope" "$path" "lib file must use guard __bebash_${expected}_loaded"
  defs=$(__bebash_verify_public_defs "$path")
  [[ -z "$defs" ]] || __bebash_verify_add fail LIB003 "$scope" "$path" "lib file must not define unprefixed public functions" "$(__bebash_verify_collapse "$defs")"
}

__bebash_verify_check_cmd() {
  local scope=$1 path=$2 sub=$3 base symbol
  base=${path##*/}
  symbol=$(__bebash_cmd_symbol "$sub")
  __bebash_verify_check_header "$scope" "$path"
  [[ "$path" == *.bash ]] || __bebash_verify_add fail SRC003 "$scope" "$path" "sourced file must end in .bash"
  __bebash_verify_bash_n "$scope" "$path"
  [[ "$base" == cmd_*.bash ]] || __bebash_verify_add fail CMD001 "$scope" "$path" "command file must be named cmd_<sub>.bash"
  grep -Eq "^[[:space:]]*(function[[:space:]]+)?bebash::cmd::${sub}([[:space:]]*\\(\\))?[[:space:]]*\\{" "$path" || \
    __bebash_verify_add fail CMD002 "$scope" "$path" "command file must define bebash::cmd::$sub"
  grep -Eq "^[[:space:]]*(function[[:space:]]+)?__bebash_cmd_${symbol}_usage([[:space:]]*\\(\\))?[[:space:]]*\\{" "$path" || \
    __bebash_verify_add fail CMD003 "$scope" "$path" "command file must define __bebash_cmd_${symbol}_usage"
}

__bebash_verify_check_rc() {
  local scope=$1 path=$2 base defs
  base=${path##*/}
  __bebash_verify_check_header "$scope" "$path"
  [[ "$path" == *.bash ]] || __bebash_verify_add fail SRC003 "$scope" "$path" "sourced file must end in .bash"
  __bebash_verify_bash_n "$scope" "$path"
  [[ "$base" =~ ^[0-9][0-9]-.+\.bash$ ]] || \
    __bebash_verify_add warn RC001 "$scope" "$path" "rc.d file should be named NN-<topic>.bash"
  defs=$(__bebash_verify_public_defs "$path")
  [[ -z "$defs" ]] || __bebash_verify_add fail RC002 "$scope" "$path" "rc.d file must not define unprefixed public functions" "$(__bebash_verify_collapse "$defs")"
}

__bebash_verify_check_config() {
  local scope=$1 path=$2
  local first second
  first=$(__bebash_verify_line "$path" 1)
  second=$(__bebash_verify_line "$path" 2)
  if [[ "$first" != '# shellcheck shell=bash' || ! "$second" =~ ^:\ \'desc:\ .+\'$ ]]; then
    __bebash_verify_add fail CONFIG001 "$scope" "$path" "config.bash must follow sourced-file header convention"
  fi
  __bebash_verify_bash_n "$scope" "$path"
}

__bebash_verify_check_disabled() {
  local scope=$1 path=$2 name=$3
  __bebash_verify_public_name "$name" || \
    __bebash_verify_add warn DISABLED001 "$scope" "$path" "disabled.d entry basename should be a valid public name"
  [[ -f "$path" || -L "$path" ]] || \
    __bebash_verify_add warn DISABLED002 "$scope" "$path" "disabled.d entries should be files or symlinks"
}

__bebash_verify_check_standalone() {
  local scope=$1 path=$2 base first
  base=${path##*/}
  first=$(__bebash_verify_line "$path" 1)
  [[ -x "$path" ]] || __bebash_verify_add fail STANDALONE001 "$scope" "$path" "standalone command must be executable"
  [[ "$first" == '#!'* ]] || __bebash_verify_add fail STANDALONE002 "$scope" "$path" "standalone command must have a shebang"
  [[ "$base" != *.bash ]] || __bebash_verify_add warn STANDALONE003 "$scope" "$path" "standalone command basename should not end in .bash"
  __bebash_verify_bash_n "$scope" "$path"
}

__bebash_verify_run_env() {
  local config data log_file log_dir tmp stale tool
  config=$(__bebash_config_dir)
  data=$(__bebash_user_data_dir)
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4))); then
    __bebash_verify_add ok ENV001 env "" "bash ${BASH_VERSION}"
  else
    __bebash_verify_add fail ENV001 env "" "bash ${BASH_VERSION}; need >=4.4"
  fi
  if [[ -r "${BEBASH_LIB}/init.bash" && -d "${BEBASH_LIB}/lib" && -r "${BEBASH_LIB}/lib/core.bash" && -d "${BEBASH_LIB}/functions" && -d "${BEBASH_LIB}/libexec/commands" && -d "${BEBASH_LIB}/rc.d" ]]; then
    __bebash_verify_add ok ENV002 env "$BEBASH_LIB" "payload root complete"
  else
    __bebash_verify_add fail ENV002 env "$BEBASH_LIB" "payload root incomplete"
  fi
  if [[ -d "$config" ]]; then
    __bebash_verify_add ok ENV003 env "$config" "config root exists"
  else
    __bebash_verify_add fail ENV003 env "$config" "config root missing; run bebash init"
  fi
  if [[ -d "$data" ]]; then
    __bebash_verify_add ok ENV004 env "$data" "data root exists"
  else
    __bebash_verify_add fail ENV004 env "$data" "data root missing; run bebash init"
  fi
  if command -v bebash >/dev/null 2>&1; then
    __bebash_verify_add ok ENV005 env "$(command -v bebash)" "bebash is on PATH"
  elif [[ -x "${__BEBASH_BIN_DIR:-}/bebash" ]]; then
    __bebash_verify_add ok ENV005 env "${__BEBASH_BIN_DIR}/bebash" "bebash is available"
  else
    __bebash_verify_add fail ENV005 env "" "bebash not found on PATH"
  fi
  log_file=$(__bebash_log_path)
  log_dir=${log_file%/*}
  if mkdir -p -- "$log_dir" 2>/dev/null && tmp=$(mktemp "$log_dir/.doctor.XXXXXX" 2>/dev/null); then
    rm -f -- "$tmp"
    __bebash_verify_add ok ENV006 env "$log_file" "log path writable"
  else
    __bebash_verify_add fail ENV006 env "$log_file" "log path is not writable"
  fi
  for tool in fzf scdoc git-cliff; do
    if command -v "$tool" >/dev/null 2>&1; then
      __bebash_verify_add ok ENV007 env "$(command -v "$tool")" "$tool available"
    else
      __bebash_verify_add warn ENV007 env "" "$tool optional tool missing"
    fi
  done
  for stale in functions lib rc.d modules; do
    if [[ -e "$config/$stale" ]]; then
      __bebash_verify_add warn ENV008 env "$config/$stale" "stale config-root code directory"
    fi
  done
}

__bebash_verify_run_structural() {
  local scope=${1:-all} record kind item_scope path expected sub file cmd seen
  while IFS= read -r -d '' record; do
    IFS=$'\t' read -r kind item_scope path expected <<<"$record"
    case "$kind" in
    function) __bebash_verify_check_function "$item_scope" "$path" "$expected" ;;
    lib) __bebash_verify_check_lib "$item_scope" "$path" "$expected" ;;
    cmd) __bebash_verify_check_cmd "$item_scope" "$path" "$expected" ;;
    rc) __bebash_verify_check_rc "$item_scope" "$path" ;;
    config) __bebash_verify_check_config "$item_scope" "$path" ;;
    disabled) __bebash_verify_check_disabled "$item_scope" "$path" "$expected" ;;
    standalone) __bebash_verify_check_standalone "$item_scope" "$path" ;;
    esac
  done < <(__bebash_verify_collect "$scope")
  if [[ "$scope" == payload || "$scope" == all ]]; then
    declare -A seen=()
    for cmd in "${__BEBASH_COMMANDS[@]:-}"; do
      file="$BEBASH_LIB/libexec/commands/cmd_${cmd}.bash"
      seen["$file"]=1
      [[ -r "$file" ]] || __bebash_verify_add fail CMD004 payload "$file" "registered command has no readable command file"
    done
    for file in "$BEBASH_LIB"/libexec/commands/cmd_*.bash; do
      [[ -e "$file" ]] || continue
      [[ -n "${seen[$file]:-}" ]] || __bebash_verify_add fail CMD004 payload "$file" "command file is not registered"
    done
  fi
  if [[ "$scope" == user || "$scope" == all ]]; then
    local config
    config=$(__bebash_config_dir)
    [[ -e "$config/AGENTS.md" ]] || \
      __bebash_verify_add warn AGENTDOC001 user "$config/AGENTS.md" "agent pointer doc missing; run bebash init --refresh-docs"
    if [[ -e "$config/AGENTS.md" ]] && ! grep -q 'bebash-agent-doc-version: 1' "$config/AGENTS.md"; then
      __bebash_verify_add warn AGENTDOC002 user "$config/AGENTS.md" "agent pointer doc is outdated; run bebash init --refresh-docs"
    fi
  fi
  local ok warn fail status
  IFS=$'\t' read -r ok warn fail < <(__bebash_verify_summary_counts)
  status=ok
  ((fail == 0)) || status=fail
  __log_info "verify run" "op=verify status=$status fail=$fail warn=$warn ok=$ok"
}

__bebash_verify_user_tool_files() {
  local config data file
  config=$(__bebash_config_dir)
  data=$(__bebash_user_data_dir)
  for file in "$config/config.bash" "$data"/functions/*.bash "$data"/lib/*.bash "$data"/rc.d/*.bash "$data"/commands/*; do
    [[ -f "$file" ]] || continue
    printf '%s\n' "$file"
  done
}

__bebash_verify_run_tools() {
  local _scope=${1:-user} mode=${2:-auto} output diff
  if [[ "$mode" == never ]]; then
    return 0
  fi
  local -a files=()
  mapfile -t files < <(__bebash_verify_user_tool_files)
  ((${#files[@]})) || return 0
  if ! command -v shellcheck >/dev/null 2>&1; then
    __bebash_verify_add warn TOOL001 user "" "shellcheck not installed; skipped user artifact shellcheck"
  else
    output=$(command shellcheck -x --rcfile "$BEBASH_LIB/.shellcheckrc" "${files[@]}" 2>&1) || \
      __bebash_verify_add fail TOOL002 user "" "shellcheck reported user artifact issues" "$(__bebash_verify_collapse "$output")"
  fi
  if ! command -v shfmt >/dev/null 2>&1; then
    __bebash_verify_add warn TOOL003 user "" "shfmt not installed; skipped user artifact format check"
  else
    local shfmt_rc=0
    diff=$(command shfmt -i 2 -ci -bn -s -d "${files[@]}" 2>&1) || shfmt_rc=$?
    # shfmt -d exits 1 when it prints a formatting diff (or a parse error) and
    # >=2 on operational errors (bad flags, unreadable files). Treat any non-empty
    # output as a TOOL004 failure so the emitted severity matches the documented
    # CONVENTIONS table; only a >=2 exit with no diff is a genuine run failure.
    if ((shfmt_rc >= 2)) && [[ -z $diff ]]; then
      __bebash_verify_add warn TOOL004 user "" "shfmt failed to run" "exit $shfmt_rc"
    elif [[ -n $diff ]]; then
      __bebash_verify_add fail TOOL004 user "" "shfmt reported user artifact formatting differences" "$(__bebash_verify_collapse "$diff")"
    fi
  fi
}
