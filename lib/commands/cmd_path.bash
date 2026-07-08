# shellcheck shell=bash
: 'desc: Print resolved bebash paths.'

__bebash_cmd_path_usage() {
  printf 'usage: bebash path [--json]\n'
}

bebash::cmd::path() {
  local json=${__BEBASH_GLOBAL[json]}
  while (($#)); do
    case "$1" in
    --json) json=1 ;;
    -h | --help)
      __bebash_cmd_path_usage
      return 0
      ;;
    --) shift && break ;;
    -*)
      bebash::die 2 "unknown flag for path: $1"
      return $?
      ;;
    *)
      bebash::die 2 "path takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($#)) && {
    bebash::die 2 "path takes no arguments"
    return $?
  }

  local payload overlay log manifest completion man
  payload=$BEBASH_LIB
  overlay=$(__bebash_overlay_dir)
  log=$(__bebash_log_path)
  manifest=$(__bebash_manifest_path)
  completion=$(__bebash_completion_path)
  man=$(__bebash_man_path)

  if ((json)); then
    printf '{'
    printf '"payload":%s,' "$(__bebash_json_string "$payload")"
    printf '"overlay":%s,' "$(__bebash_json_string "$overlay")"
    printf '"log":%s,' "$(__bebash_json_string "$log")"
    printf '"manifest":%s,' "$(__bebash_json_string "$manifest")"
    printf '"completion":%s,' "$(__bebash_json_string "$completion")"
    printf '"man":%s' "$(__bebash_json_string "$man")"
    printf '}\n'
    return 0
  fi

  printf 'payload=%s\n' "$payload"
  printf 'overlay=%s\n' "$overlay"
  printf 'log=%s\n' "$log"
  printf 'manifest=%s\n' "$manifest"
  printf 'completion=%s\n' "$completion"
  printf 'man=%s\n' "$man"
}
