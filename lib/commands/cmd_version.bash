# shellcheck shell=bash
: 'desc: Print the bebash version.'

__bebash_cmd_version_usage() {
  printf 'usage: bebash version\n'
}

bebash::cmd::version() {
  while (($#)); do
    case "$1" in
    -h | --help)
      __bebash_cmd_version_usage
      return 0
      ;;
    --) shift && break ;;
    -*)
      bebash::die 2 "unknown flag for version: $1"
      return $?
      ;;
    *)
      bebash::die 2 "version takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($#)) && {
    bebash::die 2 "version takes no arguments"
    return $?
  }

  local version_file="${BEBASH_LIB}/VERSION" version=0.0.0
  if [[ -r "$version_file" ]]; then
    IFS= read -r version <"$version_file" || version=0.0.0
  fi
  printf '%s\n' "${version#v}"
}
