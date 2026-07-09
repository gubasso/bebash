# shellcheck shell=bash
: 'desc: Find and remove broken symlinks'

__ln_clean_usage() {
  cat <<'EOF'
ln-clean - Find and remove broken symlinks

USAGE:
  ln-clean [OPTIONS] [ACTION] [PATH...]

ACTIONS:
  ls, list     List broken symlinks (default)
  rm, remove   Interactively select and remove broken symlinks

OPTIONS:
  -h, --help       Show this help message
  -n, --dry-run    Show what would be removed (rm only)
  -q, --quiet      Suppress output, exit code only
  -v, --verbose    Show symlink targets
  -d, --depth N    Limit search depth (default: unlimited)

EXIT CODES:
  0    No broken symlinks found, all removed, or help/version displayed
  1    Broken symlinks found in list mode, or an operation failed
  2    Usage error
EOF
}

__ln_clean_escape_path() {
  local s=$1
  (
    LC_ALL=C
    local out="" i=0 len=${#s} byte ord seq_len cont_byte cont_ord

    while ((i < len)); do
      byte=${s:i:1}
      printf -v ord '%d' "'$byte"

      if ((ord <= 31)) || ((ord == 127)); then
        case $ord in
        9) out+="\\t" ;;
        10) out+="\\n" ;;
        13) out+="\\r" ;;
        27) out+="\\e" ;;
        *) out+=$(printf '\\x%02x' "$ord") ;;
        esac
        ((++i))
        continue
      fi

      if ((ord >= 128 && ord <= 159)); then
        out+=$(printf '\\x%02x' "$ord")
        ((++i))
        continue
      fi

      if ((ord >= 192 && ord <= 223)); then
        if ((ord == 194 && i + 1 < len)); then
          cont_byte=${s:i+1:1}
          printf -v cont_ord '%d' "'$cont_byte"
          if ((cont_ord >= 128 && cont_ord <= 159)); then
            out+=$(printf '\\x%02x\\x%02x' "$ord" "$cont_ord")
            ((i += 2))
            continue
          fi
        fi
        seq_len=2
        ((i + seq_len <= len)) && out+="${s:i:seq_len}" || out+="${s:i}"
        ((i += seq_len))
        continue
      fi

      if ((ord >= 224 && ord <= 239)); then
        seq_len=3
        ((i + seq_len <= len)) && out+="${s:i:seq_len}" || out+="${s:i}"
        ((i += seq_len))
        continue
      fi

      if ((ord >= 240 && ord <= 247)); then
        seq_len=4
        ((i + seq_len <= len)) && out+="${s:i:seq_len}" || out+="${s:i}"
        ((i += seq_len))
        continue
      fi

      out+=$byte
      ((++i))
    done

    printf '%s' "$out"
  )
}

__ln_clean_err() {
  __ui_err "ln-clean: $*"
}

__ln_clean_log() {
  local quiet=$1
  shift
  ((quiet == 0)) && __ui_info "$*" || true
}

__ln_clean_log_verbose() {
  local quiet=$1 verbose=$2
  shift 2
  ((quiet == 0 && verbose >= 1)) && __ui_hint "$*" || true
}

__ln_clean_find_broken_links() {
  local depth=$1
  shift
  local -a paths=("$@")
  ((${#paths[@]})) || paths=(".")

  local -a find_args=()
  [[ -n "$depth" ]] && find_args+=(-maxdepth "$depth")
  find_args+=(-type l ! -exec test -e {} \; -print0)

  local path
  for path in "${paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      __ln_clean_err "Path does not exist: $(__ln_clean_escape_path "$path")"
      return 1
    fi
    command find "$path" "${find_args[@]}" 2>/dev/null || true
  done
}

__ln_clean_collect_links() {
  local __out_name=$1 depth=$2
  shift 2
  local -n __out=$__out_name
  __out=()
  local link
  while IFS= read -r -d '' link; do
    [[ -n "$link" ]] && __out+=("$link")
  done < <(__ln_clean_find_broken_links "$depth" "$@") || return 1
}

__ln_clean_list_links() {
  local quiet=$1 verbose=$2 depth=$3
  shift 3
  local -a links=()
  __ln_clean_collect_links links "$depth" "$@" || return 1
  local count=${#links[@]}

  if ((quiet == 1)); then
    ((count == 0)) && return 0 || return 1
  fi

  if ((count == 0)); then
    __ui_ok "No broken symlinks found"
    return 0
  fi

  local search_path safe_search_path link
  search_path="${*:-.}"
  safe_search_path=$(__ln_clean_escape_path "$search_path")
  __ui_info "Broken symlinks in $safe_search_path:"
  for link in "${links[@]}"; do
    local safe_link
    safe_link=$(__ln_clean_escape_path "$link")
    if ((verbose >= 1)); then
      local target safe_target
      target=$(command readlink "$link" 2>/dev/null || printf '???')
      safe_target=$(__ln_clean_escape_path "$target")
      __ui_hint "$safe_link -> $safe_target"
    else
      __ui_hint "$safe_link"
    fi
  done

  __ui_ok "Found $count broken symlink(s)"
  return 1
}

__ln_clean_remove_links() {
  local quiet=$1 verbose=$2 dry_run=$3 depth=$4
  shift 4
  local -a links=()
  __ln_clean_collect_links links "$depth" "$@" || return 1
  local count=${#links[@]}

  if ((count == 0)); then
    ((quiet == 0)) && __ui_ok "No broken symlinks found"
    return 0
  fi

  if ((dry_run == 1)); then
    __ln_clean_log "$quiet" "Would remove $count broken symlink(s):"
    local link
    for link in "${links[@]}"; do
      local safe_link
      safe_link=$(__ln_clean_escape_path "$link")
      if ((verbose >= 1)); then
        local target safe_target
        target=$(command readlink "$link" 2>/dev/null || printf '???')
        safe_target=$(__ln_clean_escape_path "$target")
        __ln_clean_log_verbose "$quiet" "$verbose" "$safe_link -> $safe_target"
      else
        __ln_clean_log_verbose "$quiet" 1 "$safe_link"
      fi
    done
    return 0
  fi

  if ((quiet == 1)); then
    local link
    for link in "${links[@]}"; do
      command rm -- "$link" || return 1
    done
    __log_info "ln-clean removed" "count=$count"
    return 0
  fi

  local -a selected=() display_lines=()
  display_lines+=("[0] ALL - Remove all $count broken symlinks")
  local i=1 link
  for link in "${links[@]}"; do
    local target safe_link safe_target
    target=$(command readlink "$link" 2>/dev/null || printf '???')
    safe_link=$(__ln_clean_escape_path "$link")
    safe_target=$(__ln_clean_escape_path "$target")
    display_lines+=("[$i] $safe_link -> $safe_target")
    ((++i))
  done

  if command -v fzf >/dev/null 2>&1; then
    local -a fzf_output=()
    local line
    while IFS= read -r line; do
      [[ -n "$line" ]] && fzf_output+=("$line")
    done < <(printf '%s\n' "${display_lines[@]}" | command fzf --multi --header="Found $count broken symlink(s) - TAB to multi-select, ENTER to confirm" 2>/dev/null || true)

    for line in "${fzf_output[@]}"; do
      if [[ $line =~ ^\[([0-9]+)\] ]]; then
        local idx=${BASH_REMATCH[1]}
        if [[ $idx == "0" ]]; then
          selected=("${links[@]}")
          break
        elif ((idx >= 1 && idx <= count)); then
          selected+=("${links[idx - 1]}")
        fi
      fi
    done
    if ((${#selected[@]} == 0)) && [[ ! -t 0 ]]; then
      __ln_clean_err "interactive selection requires a terminal; use --quiet or --dry-run"
      return 2
    fi
  else
    if [[ ! -t 0 ]]; then
      __ln_clean_err "interactive selection requires a terminal; use --quiet or --dry-run"
      return 2
    fi
    __ui_info "Broken symlinks found:"
    local line
    for line in "${display_lines[@]}"; do
      __ui_hint "$line"
    done

    local selection
    read -r -p "Enter numbers to remove (space-separated, 0 for all, empty to cancel): " selection

    if [[ -z "$selection" ]]; then
      __ui_info "No links selected."
      return 0
    fi

    local num
    for num in "${selection[@]}"; do
      if [[ $num == "0" ]]; then
        selected=("${links[@]}")
        break
      elif [[ $num =~ ^[0-9]+$ ]] && ((num >= 1 && num <= count)); then
        selected+=("${links[num - 1]}")
      else
        __ui_warn "Invalid selection: $num (skipped)"
      fi
    done
  fi

  if ((${#selected[@]} == 0)); then
    __ui_info "No links selected."
    return 0
  fi

  local removed=0
  local -a removed_links=()
  for link in "${selected[@]}"; do
    local safe_link
    safe_link=$(__ln_clean_escape_path "$link")
    if command rm -- "$link"; then
      removed_links+=("$safe_link")
      ((++removed))
    else
      __ui_warn "Failed to remove: $safe_link"
    fi
  done

  if ((removed > 0)); then
    __ui_ok "Removed $removed broken symlink(s):"
    local safe_link
    for safe_link in "${removed_links[@]}"; do
      __ui_hint "$safe_link"
    done
    __log_info "ln-clean removed" "count=$removed"
  else
    __ui_warn "No links were removed"
  fi
}

ln-clean() {
  local quiet=0 verbose=0 dry_run=0 depth="" action="ls"
  local -a paths=()

  while (($#)); do
    case "$1" in
    -h | --help)
      __ln_clean_usage
      return 0
      ;;
    -n | --dry-run)
      dry_run=1
      shift
      ;;
    -q | --quiet)
      quiet=1
      shift
      ;;
    -v | --verbose)
      ((++verbose))
      shift
      ;;
    -d | --depth)
      (($# >= 2)) || {
        __ln_clean_err "Option -d requires a number"
        return 2
      }
      depth=$2
      [[ $depth =~ ^[0-9]+$ ]] || {
        __ln_clean_err "Depth must be a non-negative integer"
        return 2
      }
      shift 2
      ;;
    ls | list)
      action="ls"
      shift
      ;;
    rm | remove)
      action="rm"
      shift
      ;;
    -*)
      __ln_clean_err "Unknown option: $(__ln_clean_escape_path "$1")"
      return 2
      ;;
    *)
      paths+=("$1")
      shift
      ;;
    esac
  done

  case "$action" in
  ls) __ln_clean_list_links "$quiet" "$verbose" "$depth" "${paths[@]}" ;;
  rm) __ln_clean_remove_links "$quiet" "$verbose" "$dry_run" "$depth" "${paths[@]}" ;;
  esac
}
