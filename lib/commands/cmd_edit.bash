# shellcheck shell=bash
: 'desc: Edit an overlay function.'

__bebash_cmd_edit_usage() {
  printf 'usage: bebash edit [--new] <function>\n'
}

__bebash_valid_function_name() {
  [[ ${1-} =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]]
}

__bebash_find_function_file() {
  local name=$1 overlay shipped
  overlay="$(__bebash_overlay_dir)/functions/$name.bash"
  shipped="${BEBASH_LIB}/lib/functions/$name.bash"
  if [[ -e "$overlay" ]]; then
    printf '%s\n' "$overlay"
  elif [[ -e "$shipped" ]]; then
    printf '%s\n' "$shipped"
  else
    return 1
  fi
}

__bebash_scaffold_function() {
  local name=$1 target=$2 template tmp
  template="${BEBASH_LIB}/lib/templates/function.bash"
  mkdir -p -- "${target%/*}" || return 73
  [[ -e "$target" ]] && return 0
  tmp="$target.tmp.$$"
  if [[ -r "$template" ]]; then
    while IFS= read -r line; do
      line=${line//__BEBASH_FUNCTION_NAME__/$name}
      printf '%s\n' "$line"
    done <"$template" >"$tmp" || {
      rm -f -- "$tmp"
      return 73
    }
  else
    {
      printf '%s\n' '# shellcheck shell=bash'
      printf ": 'desc: %s.'\n" "$name"
      printf '\n'
      printf '%s() {\n' "$name"
      printf '  :\n'
      printf '}\n'
    } >"$tmp" || {
      rm -f -- "$tmp"
      return 73
    }
  fi
  mv -f -- "$tmp" "$target" || {
    rm -f -- "$tmp"
    return 73
  }
}

bebash::cmd::edit() {
  local create=0 name='' file rc
  while (($#)); do
    case "$1" in
    --new) create=1 ;;
    -h | --help)
      __bebash_cmd_edit_usage
      return 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      bebash::die 2 "unknown flag for edit: $1"
      return $?
      ;;
    *)
      [[ -z "$name" ]] || {
        bebash::die 2 "edit takes one function name"
        return $?
      }
      name=$1
      ;;
    esac
    shift
  done
  if (($#)); then
    [[ -z "$name" ]] || {
      bebash::die 2 "edit takes one function name"
      return $?
    }
    name=$1
    shift
  fi
  (($# == 0)) || {
    bebash::die 2 "edit takes one function name"
    return $?
  }
  [[ -n "$name" ]] || {
    bebash::die 2 "edit requires a function name"
    return $?
  }
  __bebash_valid_function_name "$name" || {
    bebash::die 2 "invalid function name: $name"
    return $?
  }
  [[ -n "${EDITOR:-}" ]] || {
    bebash::die 69 "EDITOR is not set"
    return $?
  }

  if ((create)); then
    file="$(__bebash_overlay_dir)/functions/$name.bash"
    __bebash_scaffold_function "$name" "$file"
    rc=$?
    ((rc == 0)) || {
      bebash::die "$rc" "could not create function: $file"
      return $?
    }
  else
    file=$(__bebash_find_function_file "$name") || {
      bebash::die 2 "function not found: $name"
      return $?
    }
  fi

  local -a editor_cmd
  read -r -a editor_cmd <<<"$EDITOR"
  command "${editor_cmd[@]}" "$file" || return $?
}
