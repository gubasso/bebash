# shellcheck shell=bash
: 'desc: Scaffold user config and data directories.'

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

  local config data config_template dir tmp
  config=$(__bebash_config_dir)
  data=$(__bebash_user_data_dir)
  config_template="${BEBASH_LIB}/templates/config.bash"
  for dir in "$config/disabled.d" "$data/functions" "$data/lib" "$data/rc.d" "$data/commands"; do
    mkdir -p -- "$dir" || {
      bebash::die 73 "could not create directory: $dir"
      return $?
    }
  done

  if [[ ! -e "$config/config.bash" ]]; then
    mkdir -p -- "$config" || {
      bebash::die 73 "could not create config directory: $config"
      return $?
    }
    tmp="$config/config.bash.tmp.$$"
    if [[ -r "$config_template" ]]; then
      cp -- "$config_template" "$tmp" || {
        rm -f -- "$tmp"
        bebash::die 73 "could not create config: $config/config.bash"
        return $?
      }
    else
      printf '%s\n' '# shellcheck shell=bash' ": 'desc: user config'" >"$tmp" || {
        rm -f -- "$tmp"
        bebash::die 73 "could not create config: $config/config.bash"
        return $?
      }
    fi
    mv -f -- "$tmp" "$config/config.bash" || {
      rm -f -- "$tmp"
      bebash::die 73 "could not create config: $config/config.bash"
      return $?
    }
  fi

  __bebash_ui_info "config ready: $config"
  __bebash_ui_info "data ready: $data"
  printf 'config=%s\n' "$config"
  printf 'data=%s\n' "$data"
}
