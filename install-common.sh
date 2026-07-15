#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

__bebash_install_resolve_self_dir() {
  local src=${BASH_SOURCE[1]}
  while [[ -L $src ]]; do
    local dir
    dir=$(cd -P -- "$(dirname -- "$src")" && pwd)
    src=$(readlink -- "$src")
    [[ $src != /* ]] && src=$dir/$src
  done
  cd -P -- "$(dirname -- "$src")" && pwd
}

__bebash_install_resolve_targets() {
  if [[ -z ${PREFIX:-} ]]; then
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
      PREFIX=/usr/local
    else
      PREFIX=$HOME/.local
    fi
  fi

  if [[ -z ${XDG_DATA_HOME:-} ]]; then
    if [[ ${EUID:-$(id -u)} -eq 0 && $PREFIX == /usr/local ]]; then
      XDG_DATA_HOME=/usr/local/share
    else
      XDG_DATA_HOME=$HOME/.local/share
    fi
  fi

  if [[ -z ${XDG_STATE_HOME:-} ]]; then
    if [[ ${EUID:-$(id -u)} -eq 0 && $PREFIX == /usr/local ]]; then
      XDG_STATE_HOME=/var/lib
    else
      XDG_STATE_HOME=$HOME/.local/state
    fi
  fi

  if [[ -z ${XDG_CONFIG_HOME:-} ]]; then
    XDG_CONFIG_HOME=$HOME/.config
  fi

  BEBASH_INSTALL_PREFIX=$PREFIX
  BEBASH_INSTALL_APP_ROOT=$BEBASH_INSTALL_PREFIX/lib/bebash
  BEBASH_INSTALL_BIN_BEBASH=$BEBASH_INSTALL_PREFIX/bin/bebash
  BEBASH_INSTALL_BIN_BEBASH_CMD=$BEBASH_INSTALL_PREFIX/bin/bebash-cmd
  BEBASH_INSTALL_DATA_HOME=$XDG_DATA_HOME
  BEBASH_INSTALL_STATE_HOME=$XDG_STATE_HOME
  # shellcheck disable=SC2034  # resolved target retained for parity with other XDG homes
  BEBASH_INSTALL_CONFIG_HOME=$XDG_CONFIG_HOME
  BEBASH_INSTALL_COMPLETION=$BEBASH_INSTALL_DATA_HOME/bash-completion/completions/bebash
  BEBASH_INSTALL_MANPAGE=$BEBASH_INSTALL_DATA_HOME/man/man1/bebash.1
  BEBASH_INSTALL_STATE_DIR=$BEBASH_INSTALL_STATE_HOME/bebash
  export BEBASH_INSTALL_MANIFEST=$BEBASH_INSTALL_STATE_DIR/install-manifest
}

__bebash_install_mkdir_parent() {
  mkdir -p -- "$(dirname -- "$1")"
}

__bebash_install_record() {
  local path=$1 manifest=$2
  [[ $path == /* ]] || {
    printf 'bebash: refusing to record non-absolute path: %s\n' "$path" >&2
    return 1
  }
  printf '%s\n' "$path" >>"$manifest"
}

__bebash_install_sort_manifest() {
  local manifest=$1
  LC_ALL=C sort -u -o "$manifest" -- "$manifest"
}

__bebash_install_under_root() {
  local path=$1 root=$2
  [[ $path == "$root" || $path == "$root"/* ]]
}

__bebash_install_path_allowed() {
  local path=$1
  # Reject any traversal segment: a whitelist prefix check on an
  # uncanonicalized path could otherwise be escaped by `..` (e.g.
  # "$APP_ROOT/../../outside" matches the prefix yet resolves outside).
  case $path in
    */../* | */.. | ../* | ..) return 1 ;;
  esac
  __bebash_install_under_root "$path" "$BEBASH_INSTALL_APP_ROOT" && return 0
  __bebash_install_under_root "$path" "$BEBASH_INSTALL_STATE_DIR" && return 0
  [[ $path == "$BEBASH_INSTALL_BIN_BEBASH" ]] && return 0
  [[ $path == "$BEBASH_INSTALL_BIN_BEBASH_CMD" ]] && return 0
  [[ $path == "$BEBASH_INSTALL_COMPLETION" ]] && return 0
  [[ $path == "$BEBASH_INSTALL_MANPAGE" ]] && return 0
  return 1
}

__bebash_install_validate_manifest() {
  local manifest=$1 path
  [[ -e $manifest ]] || return 0
  while IFS= read -r path || [[ -n $path ]]; do
    [[ -n $path ]] || continue
    if [[ $path != /* ]]; then
      printf 'bebash: manifest contains non-absolute path: %s\n' "$path" >&2
      return 1
    fi
    if ! __bebash_install_path_allowed "$path"; then
      printf 'bebash: manifest path outside install roots: %s\n' "$path" >&2
      printf 'bebash:   current roots: PREFIX=%s XDG_DATA_HOME=%s XDG_STATE_HOME=%s\n' \
        "$BEBASH_INSTALL_PREFIX" "$BEBASH_INSTALL_DATA_HOME" "$BEBASH_INSTALL_STATE_HOME" >&2
      printf 'bebash:   if PREFIX/XDG_* changed since the last install, re-run with the same values;\n' >&2
      printf 'bebash:   otherwise remove the stale manifest and retry: rm -f %s\n' "$manifest" >&2
      return 1
    fi
  done <"$manifest"
}

__bebash_install_prune_empty_dirs() {
  local dir
  for dir in \
    "$BEBASH_INSTALL_APP_ROOT/bin" \
    "$BEBASH_INSTALL_APP_ROOT/libexec/commands" \
    "$BEBASH_INSTALL_APP_ROOT/libexec" \
    "$BEBASH_INSTALL_APP_ROOT/functions" \
    "$BEBASH_INSTALL_APP_ROOT/rc.d" \
    "$BEBASH_INSTALL_APP_ROOT/templates" \
    "$BEBASH_INSTALL_APP_ROOT/lib/commands" \
    "$BEBASH_INSTALL_APP_ROOT/lib/functions" \
    "$BEBASH_INSTALL_APP_ROOT/lib/rc.d" \
    "$BEBASH_INSTALL_APP_ROOT/lib/templates" \
    "$BEBASH_INSTALL_APP_ROOT/lib" \
    "$BEBASH_INSTALL_APP_ROOT" \
    "$(dirname -- "$BEBASH_INSTALL_BIN_BEBASH")" \
    "$(dirname -- "$BEBASH_INSTALL_COMPLETION")" \
    "$(dirname -- "$BEBASH_INSTALL_COMPLETION")/.." \
    "$(dirname -- "$BEBASH_INSTALL_MANPAGE")" \
    "$(dirname -- "$BEBASH_INSTALL_MANPAGE")/.." \
    "$BEBASH_INSTALL_STATE_DIR"; do
    [[ -d $dir ]] || continue
    rmdir -- "$dir" 2>/dev/null || true
  done
}

# NOTE: bebash's installer never edits the user's shell rc (`~/.bashrc`). That is
# user-authored *configuration* — one writer per file: humans and config managers
# write config, the installer only writes its own payload and state. Shell
# integration (sourcing `<app-root>/init.bash`) is a manual, documented step (or
# owned by a config manager such as Home Manager / stow). See ADR-0033 and
# docs/guides/installing-bebash.md.
