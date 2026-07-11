# shellcheck shell=bash
: 'desc: Initialize a bebash user overlay.'

__bebash_cmd_init_usage() {
  printf 'usage: bebash init [--location xdg|dotfiles|custom] [--path DIR] [--refresh-docs] [--no-doctor]\n'
}

__bebash_init_write_config_fallback() {
  printf '%s\n' '# shellcheck shell=bash'
  printf '%s\n' ": 'desc: user config'"
}

__bebash_init_write_agent_fallback() {
  printf '%s\n' '<!-- bebash-agent-doc-version: 1 -->'
  printf '%s\n' '# bebash overlay'
  # shellcheck disable=SC2016 # literal backticks are Markdown, not shell expansion
  printf '%s\n' 'Run `bebash man`, `bebash help <cmd>`, and `bebash doctor` for the live reference.'
}

__bebash_init_write_readme_fallback() {
  printf '%s\n' '<!-- bebash-user-readme-version: 1 -->'
  printf '%s\n' '# bebash user overlay'
  printf '%s\n' 'This directory contains your bebash config and overlay files.'
}

__bebash_init_copy_if_needed() {
  local template=$1 target=$2 marker=$3 refresh=$4 fallback_fn=$5 tmp
  if [[ -e "$target" ]]; then
    ((refresh)) || return 0
    if ! grep -q "$marker" "$target"; then
      __bebash_ui_warn "skipping user-edited doc: $target"
      return 0
    fi
  fi
  mkdir -p -- "${target%/*}" || return 73
  tmp="$target.tmp.$$"
  if [[ -r "$template" ]]; then
    cp -- "$template" "$tmp" || {
      rm -f -- "$tmp"
      return 73
    }
  else
    "$fallback_fn" >"$tmp" || {
      rm -f -- "$tmp"
      return 73
    }
  fi
  mv -f -- "$tmp" "$target" || {
    rm -f -- "$tmp"
    return 73
  }
}

__bebash_init_link_root() {
  local link=$1 target=$2
  mkdir -p -- "$target" || return 73
  if [[ -L "$link" ]]; then
    local current
    current=$(readlink -- "$link") || return 73
    if [[ "$current" == "$target" ]]; then
      return 0
    fi
    rm -f -- "$link" || return 73
  elif [[ -e "$link" ]]; then
    __bebash_ui_err "refusing to replace existing non-symlink root: $link"
    __ui_hint "move it aside or set BEBASH_CONFIG_DIR/BEBASH_DATA_DIR before initializing"
    return 73
  else
    mkdir -p -- "${link%/*}" || return 73
  fi
  ln -s -- "$target" "$link" || return 73
}

__bebash_init_choose_location() {
  local reply
  printf 'Choose overlay location:\n' >&2
  printf '  1) XDG roots under this home\n' >&2
  printf '  2) dotfiles tree at ~/.dotfiles/bebash\n' >&2
  printf '  3) custom path\n' >&2
  read -r -p 'Location [1-3]: ' reply
  case "$reply" in
  1 | '') printf 'xdg\n' ;;
  2) printf 'dotfiles\n' ;;
  3) printf 'custom\n' ;;
  *) return 2 ;;
  esac
}

bebash::cmd::init() {
  local location='' base_path='' refresh_docs=0 run_doctor=1 config data config_template rc
  # __BEBASH_GLOBAL is declared in lib/core.bash and shared across the CLI
  # shellcheck disable=SC2154
  while (($#)); do
    case "$1" in
    --location)
      shift
      (($#)) || {
        bebash::die 2 "--location requires xdg, dotfiles, or custom"
        return $?
      }
      location=$1
      ;;
    --location=*) location=${1#--location=} ;;
    --path)
      shift
      (($#)) || {
        bebash::die 2 "--path requires a directory"
        return $?
      }
      base_path=$1
      ;;
    --path=*) base_path=${1#--path=} ;;
    --refresh-docs) refresh_docs=1 ;;
    --no-doctor) run_doctor=0 ;;
    --non-interactive) __BEBASH_GLOBAL[non_interactive]=1 ;;
    -y | --yes) __BEBASH_GLOBAL[yes]=1 ;;
    -h | --help)
      __bebash_cmd_init_usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      bebash::die 2 "unknown flag for init: $1"
      return $?
      ;;
    *)
      bebash::die 2 "init takes no arguments"
      return $?
      ;;
    esac
    shift
  done
  (($# == 0)) || {
    bebash::die 2 "init takes no arguments"
    return $?
  }
  if [[ -z "$location" ]]; then
    if ((__BEBASH_GLOBAL[non_interactive])); then
      location=xdg
    elif [[ -t 0 ]]; then
      location=$(__bebash_init_choose_location) || {
        bebash::die 2 "invalid location choice"
        return $?
      }
    else
      bebash::die 2 "init requires --location in non-TTY mode"
      return $?
    fi
  fi
  case "$location" in
  xdg)
    config=$(__bebash_config_dir)
    data=$(__bebash_user_data_dir)
    ;;
  dotfiles)
    [[ -n "$base_path" ]] || base_path="$HOME/.dotfiles/bebash"
    config="$base_path/.config/bebash"
    data="$base_path/.local/share/bebash"
    __bebash_init_link_root "$(__bebash_config_dir)" "$config" || {
      bebash::die 73 "could not wire config root: $(__bebash_config_dir)"
      return $?
    }
    __bebash_init_link_root "$(__bebash_user_data_dir)" "$data" || {
      bebash::die 73 "could not wire data root: $(__bebash_user_data_dir)"
      return $?
    }
    ;;
  custom)
    [[ -n "$base_path" ]] || {
      bebash::die 2 "--location custom requires --path DIR"
      return $?
    }
    config="$base_path/.config/bebash"
    data="$base_path/.local/share/bebash"
    __bebash_init_link_root "$(__bebash_config_dir)" "$config" || {
      bebash::die 73 "could not wire config root: $(__bebash_config_dir)"
      return $?
    }
    __bebash_init_link_root "$(__bebash_user_data_dir)" "$data" || {
      bebash::die 73 "could not wire data root: $(__bebash_user_data_dir)"
      return $?
    }
    ;;
  *)
    bebash::die 2 "--location requires xdg, dotfiles, or custom"
    return $?
    ;;
  esac

  local dir
  for dir in "$config/disabled.d" "$data/functions" "$data/lib" "$data/rc.d" "$data/commands"; do
    mkdir -p -- "$dir" || {
      bebash::die 73 "could not create directory: $dir"
      return $?
    }
  done

  config_template="${BEBASH_LIB}/templates/config.bash"
  if [[ ! -e "$config/config.bash" ]]; then
    __bebash_init_copy_if_needed "$config_template" "$config/config.bash" "desc:" 0 __bebash_init_write_config_fallback || {
      rc=$?
      bebash::die "$rc" "could not create config: $config/config.bash"
      return $?
    }
  fi
  __bebash_init_copy_if_needed "$BEBASH_LIB/templates/user-readme.md" "$config/README.md" "bebash-user-readme-version: 1" "$refresh_docs" __bebash_init_write_readme_fallback || {
    rc=$?
    bebash::die "$rc" "could not deploy README.md"
    return $?
  }
  __bebash_init_copy_if_needed "$BEBASH_LIB/templates/AGENTS.md" "$config/AGENTS.md" "bebash-agent-doc-version: 1" "$refresh_docs" __bebash_init_write_agent_fallback || {
    rc=$?
    bebash::die "$rc" "could not deploy AGENTS.md"
    return $?
  }

  printf 'location=%s\n' "$location"
  printf 'config=%s\n' "$config"
  printf 'data=%s\n' "$data"
  printf 'agent_doc=%s\n' "$config/AGENTS.md"

  if ((run_doctor)); then
    # shellcheck source=libexec/commands/cmd_doctor.bash
    source "$BEBASH_LIB/libexec/commands/cmd_doctor.bash"
    bebash::cmd::doctor --scope user
    return $?
  fi
  return 0
}
