# shellcheck shell=bash
: 'desc: List available bebash functions.'

__bebash_cmd_list_usage() {
  printf 'usage: bebash list [--json]\n'
}

__bebash_desc_from_file() {
  local file=$1 line desc
  while IFS= read -r line; do
    [[ "$line" == ": 'desc: "* ]] || continue
    desc=${line#": 'desc: "}
    desc=${desc%\'}
    printf '%s\n' "$desc"
    return 0
  done <"$file"
  printf '\n'
}

__bebash_iter_function_files() {
  local origin dir file name desc
  for origin in shipped data; do
    if [[ "$origin" == shipped ]]; then
      dir="${BEBASH_LIB}/functions"
    else
      dir="$(__bebash_user_data_dir)/functions"
    fi
    [[ -d "$dir" ]] || continue
    for file in "$dir"/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      name=${name%.bash}
      desc=$(__bebash_desc_from_file "$file")
      printf '%s\t%s\t%s\n' "$name" "$desc" "$origin"
    done
  done
}

bebash::cmd::list() {
  local json=${__BEBASH_GLOBAL[json]}
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    -h | --help)
      __bebash_cmd_list_usage
      return 0
      ;;
    --) shift && break ;;
    -*)
      bebash::die 2 "unknown flag for list: $1"
      return $?
      ;;
    *)
      bebash::die 2 "list takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($#)) && {
    bebash::die 2 "list takes no arguments"
    return $?
  }

  local line name desc origin existing
  local -A desc_by_name=() origin_by_name=()
  while IFS=$'\t' read -r name desc origin; do
    [[ -n "$name" ]] || continue
    desc_by_name[$name]=$desc
    origin_by_name[$name]=$origin
  done < <(__bebash_iter_function_files)

  if ((json)); then
    local first=1
    printf '['
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      ((first)) || printf ','
      first=0
      printf '{"name":%s,"desc":%s,"origin":%s}' \
        "$(__bebash_json_string "$name")" \
        "$(__bebash_json_string "${desc_by_name[$name]}")" \
        "$(__bebash_json_string "${origin_by_name[$name]}")"
    done < <(printf '%s\n' "${!desc_by_name[@]}" | LC_ALL=C sort)
    printf ']\n'
    return 0
  fi

  while IFS= read -r existing; do
    [[ -n "$existing" ]] || continue
    line=$(printf '%s  %s  %s' "$existing" "${desc_by_name[$existing]}" "${origin_by_name[$existing]}")
    printf '%s\n' "$line"
  done < <(printf '%s\n' "${!desc_by_name[@]}" | LC_ALL=C sort)
}
