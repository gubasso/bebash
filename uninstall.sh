#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

__bebash_uninstall_resolve_script_dir() {
  local src=${BASH_SOURCE[0]}
  while [[ -L $src ]]; do
    local dir
    dir=$(cd -P -- "$(dirname -- "$src")" && pwd)
    src=$(readlink -- "$src")
    [[ $src != /* ]] && src=$dir/$src
  done
  cd -P -- "$(dirname -- "$src")" && pwd
}

script_dir=$(__bebash_uninstall_resolve_script_dir)
# shellcheck source=install-common.sh
source "$script_dir/install-common.sh"
__bebash_install_resolve_targets

if [[ ! -e $BEBASH_INSTALL_MANIFEST ]]; then
  printf 'bebash manifest not found; nothing to uninstall\n' >&2
  exit 0
fi

__bebash_install_validate_manifest "$BEBASH_INSTALL_MANIFEST"

while IFS= read -r path || [[ -n $path ]]; do
  [[ -n $path ]] || continue
  rm -f -- "$path"
done <"$BEBASH_INSTALL_MANIFEST"

commands_manifest=$BEBASH_INSTALL_STATE_DIR/commands-manifest
if [[ -e $commands_manifest ]]; then
  while IFS= read -r path || [[ -n $path ]]; do
    [[ -n $path ]] || continue
    if [[ -L $path ]]; then
      target=$(readlink -- "$path") || target=
      [[ $target != /* && -n $target ]] && target=$(cd -P -- "$(dirname -- "$path")" && pwd)/$target
      [[ $target == "$BEBASH_INSTALL_BIN_BEBASH_CMD" ]] && rm -f -- "$path"
    fi
  done <"$commands_manifest"
  rm -f -- "$commands_manifest"
fi

__bebash_install_prune_empty_dirs
rm -f -- "$BEBASH_INSTALL_MANIFEST"
__bebash_install_prune_empty_dirs

printf 'bebash uninstalled\n' >&2
printf 'If you added a bebash source line to your shell rc, remove it manually\n' >&2
printf '(the installer never edited it). Config managers own their own wiring.\n' >&2
