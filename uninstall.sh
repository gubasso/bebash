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
  __bebash_install_strip_bashrc_block "$BEBASH_INSTALL_BASHRC"
  printf 'bebash manifest not found; stripped shell marker block if present\n' >&2
  exit 0
fi

__bebash_install_validate_manifest "$BEBASH_INSTALL_MANIFEST"

while IFS= read -r path || [[ -n $path ]]; do
  [[ -n $path ]] || continue
  rm -f -- "$path"
done <"$BEBASH_INSTALL_MANIFEST"

__bebash_install_prune_empty_dirs
__bebash_install_strip_bashrc_block "$BEBASH_INSTALL_BASHRC"
rm -f -- "$BEBASH_INSTALL_MANIFEST"
__bebash_install_prune_empty_dirs

printf 'bebash uninstalled\n' >&2
