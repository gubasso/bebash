# shellcheck shell=bash
: 'desc: eager helper functions'

[[ -n "${__bebash_helpers_loaded:-}" ]] && return 0
__bebash_helpers_loaded=1

__require() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || return 1
  done
}

__require_verbose() {
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]})); then
    __ui_err "Missing dependencies: ${missing[*]}"
    return 1
  fi
  return 0
}

__array_contains() {
  local needle=${1-} item
  shift || return 1
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

__is_tty() {
  case "${TERM:-}" in
  linux | linux-* | vt* | dumb) return 0 ;;
  esac
  [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && "${XDG_SESSION_TYPE:-}" == tty ]]
}

__is_graphical() {
  [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

__path_prepend() {
  local dir=${1:-}
  [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]] && PATH="$dir:$PATH"
  return 0
}

__cached_init() {
  local tool=${1:-}
  shift || {
    __ui_err "__cached_init: missing tool"
    return 2
  }

  local cache_base=${XDG_CACHE_HOME:-$HOME/.cache}
  [[ "$cache_base" = /* ]] || cache_base=$HOME/.cache
  local cache_dir="$cache_base/bebash"
  mkdir -p -- "$cache_dir" 2>/dev/null || {
    __ui_err "__cached_init: no writable cache directory for $tool"
    return 1
  }

  local cache_file="$cache_dir/$tool.bash" tool_path
  tool_path=$(command -v "$tool" 2>/dev/null) || return 1

  if [[ -s "$cache_file" && "$cache_file" -nt "$tool_path" ]]; then
    # shellcheck source=/dev/null
    if source "$cache_file" 2>/dev/null; then
      return 0
    fi
    rm -f -- "$cache_file"
  fi

  local tmp_file="$cache_file.tmp.$$"
  if "$@" >"$tmp_file" 2>/dev/null; then
    if [[ -s "$tmp_file" ]]; then
      mv -f -- "$tmp_file" "$cache_file"
      # shellcheck source=/dev/null
      source "$cache_file"
    else
      rm -f -- "$tmp_file"
    fi
  else
    rm -f -- "$tmp_file"
    __ui_err "__cached_init: $tool init failed"
    return 1
  fi
}

__with_browser_shim() {
  local -a browser_args=()
  local found_sep=0
  while (($#)); do
    if [[ "$1" == "--" ]]; then
      found_sep=1
      shift
      break
    fi
    browser_args+=("$1")
    shift
  done
  ((found_sep)) || {
    __ui_err "__with_browser_shim: missing -- separator"
    return 2
  }
  (($#)) || {
    __ui_err "__with_browser_shim: missing command"
    return 2
  }
  __require_verbose xdg-open || return 1
  BROWSER="xdg-open ${browser_args[*]}" "$@"
}
