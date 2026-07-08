# shellcheck shell=bash
: 'desc: Scaffold the user overlay.'

__bebash_cmd_init_user_usage() {
  printf 'usage: bebash init-user\n'
}

bebash::cmd::init-user() {
  while (($#)); do
    case "$1" in
    -h | --help)
      __bebash_cmd_init_user_usage
      return 0
      ;;
    --) shift && break ;;
    -*)
      bebash::die 2 "unknown flag for init-user: $1"
      return $?
      ;;
    *)
      bebash::die 2 "init-user takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($#)) && {
    bebash::die 2 "init-user takes no arguments"
    return $?
  }

  local overlay config_template dir tmp
  overlay=$(__bebash_overlay_dir)
  config_template="${BEBASH_LIB}/lib/templates/config.bash"
  for dir in functions lib rc.d disabled.d; do
    mkdir -p -- "$overlay/$dir" || {
      bebash::die 73 "could not create overlay directory: $overlay/$dir"
      return $?
    }
  done

  if [[ ! -e "$overlay/config.bash" ]]; then
    tmp="$overlay/config.bash.tmp.$$"
    if [[ -r "$config_template" ]]; then
      cp -- "$config_template" "$tmp" || {
        rm -f -- "$tmp"
        bebash::die 73 "could not create overlay config: $overlay/config.bash"
        return $?
      }
    else
      printf '%s\n' '# shellcheck shell=bash' ": 'desc: user overlay config'" >"$tmp" || {
        rm -f -- "$tmp"
        bebash::die 73 "could not create overlay config: $overlay/config.bash"
        return $?
      }
    fi
    mv -f -- "$tmp" "$overlay/config.bash" || {
      rm -f -- "$tmp"
      bebash::die 73 "could not create overlay config: $overlay/config.bash"
      return $?
    }
  fi

  __bebash_ui_info "overlay ready: $overlay"
  printf '%s\n' "$overlay"
}
