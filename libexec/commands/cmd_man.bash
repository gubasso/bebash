# shellcheck shell=bash
: 'desc: Print the bebash reference manual.'

__bebash_cmd_man_usage() {
  printf 'usage: bebash man [--source]\n'
}

__bebash_man_source() {
  local candidate repo_root
  candidate="$BEBASH_LIB/man/bebash.1.scd"
  [[ -r "$candidate" ]] && {
    printf '%s\n' "$candidate"
    return 0
  }
  repo_root=$(cd -P -- "$BEBASH_LIB" 2>/dev/null && pwd)
  candidate="$repo_root/man/bebash.1.scd"
  [[ -r "$candidate" ]] && {
    printf '%s\n' "$candidate"
    return 0
  }
  candidate=$(__bebash_man_path)
  [[ -r "$candidate" ]] && {
    printf '%s\n' "$candidate"
    return 0
  }
  return 1
}

__bebash_man_plain() {
  sed \
    -e 's/.\x08//g' \
    -e 's/^# \(.*\)$/\1/' \
    -e 's/\*//g' \
    -e 's/^;//' \
    "$1"
}

bebash::cmd::man() {
  local source_mode=0 source_file
  while (($#)); do
    case "$1" in
    --source) source_mode=1 ;;
    -h | --help)
      __bebash_cmd_man_usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      bebash::die 2 "unknown flag for man: $1"
      return $?
      ;;
    *)
      bebash::die 2 "man takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($# == 0)) || {
    bebash::die 2 "man takes no arguments"
    return $?
  }
  source_file=$(__bebash_man_source) || {
    bebash::die 66 "manual source not found"
    return $?
  }
  if ((source_mode)); then
    cat -- "$source_file"
  else
    __bebash_man_plain "$source_file"
  fi
}
