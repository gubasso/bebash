#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

__bebash_install_resolve_repo_root() {
  local src=${BASH_SOURCE[0]}
  while [[ -L $src ]]; do
    local dir
    dir=$(cd -P -- "$(dirname -- "$src")" && pwd)
    src=$(readlink -- "$src")
    [[ $src != /* ]] && src=$dir/$src
  done
  cd -P -- "$(dirname -- "$src")" && pwd
}

__bebash_install_copy_tree() {
  local src=$1 dest=$2 manifest=$3 path
  rm -rf -- "$dest"
  mkdir -p -- "$dest"
  cp -R -- "$src"/. "$dest"/
  while IFS= read -r path; do
    __bebash_install_record "$path" "$manifest"
  done < <(find "$dest" -type f -o -type l | LC_ALL=C sort)
}

__bebash_install_remove_stale() {
  local old_manifest=$1 new_manifest=$2 stale
  [[ -e $old_manifest ]] || return 0
  __bebash_install_validate_manifest "$old_manifest"
  while IFS= read -r stale; do
    [[ -n $stale ]] || continue
    __bebash_install_path_allowed "$stale" || {
      printf 'bebash: refusing stale path outside install roots: %s\n' "$stale" >&2
      return 1
    }
    rm -f -- "$stale"
  done < <(comm -23 "$old_manifest" "$new_manifest")
  __bebash_install_prune_empty_dirs
}

repo_root=$(__bebash_install_resolve_repo_root)
script_dir=$repo_root
# shellcheck source=install-common.sh
source "$script_dir/install-common.sh"
__bebash_install_resolve_targets

mkdir -p -- "$BEBASH_INSTALL_STATE_DIR"
tmp_manifest=$(mktemp "$BEBASH_INSTALL_STATE_DIR/install-manifest.XXXXXX")
cleanup() {
  rm -f -- "$tmp_manifest"
}
trap cleanup EXIT INT TERM

rm -rf -- \
  "${BEBASH_INSTALL_APP_ROOT:?}/bin" \
  "${BEBASH_INSTALL_APP_ROOT:?}/lib" \
  "${BEBASH_INSTALL_APP_ROOT:?}/libexec" \
  "${BEBASH_INSTALL_APP_ROOT:?}/functions" \
  "${BEBASH_INSTALL_APP_ROOT:?}/rc.d" \
  "${BEBASH_INSTALL_APP_ROOT:?}/templates" \
  "$BEBASH_INSTALL_APP_ROOT/init.bash" \
  "$BEBASH_INSTALL_APP_ROOT/init-headless.bash" \
  "$BEBASH_INSTALL_APP_ROOT/VERSION"
mkdir -p -- "$BEBASH_INSTALL_APP_ROOT"

__bebash_install_copy_tree "$repo_root/lib" "$BEBASH_INSTALL_APP_ROOT/lib" "$tmp_manifest"
__bebash_install_copy_tree "$repo_root/libexec" "$BEBASH_INSTALL_APP_ROOT/libexec" "$tmp_manifest"
__bebash_install_copy_tree "$repo_root/functions" "$BEBASH_INSTALL_APP_ROOT/functions" "$tmp_manifest"
__bebash_install_copy_tree "$repo_root/rc.d" "$BEBASH_INSTALL_APP_ROOT/rc.d" "$tmp_manifest"
__bebash_install_copy_tree "$repo_root/templates" "$BEBASH_INSTALL_APP_ROOT/templates" "$tmp_manifest"

cp -- "$repo_root/init.bash" "$BEBASH_INSTALL_APP_ROOT/init.bash"
__bebash_install_record "$BEBASH_INSTALL_APP_ROOT/init.bash" "$tmp_manifest"
cp -- "$repo_root/init-headless.bash" "$BEBASH_INSTALL_APP_ROOT/init-headless.bash"
__bebash_install_record "$BEBASH_INSTALL_APP_ROOT/init-headless.bash" "$tmp_manifest"
cp -- "$repo_root/VERSION" "$BEBASH_INSTALL_APP_ROOT/VERSION"
__bebash_install_record "$BEBASH_INSTALL_APP_ROOT/VERSION" "$tmp_manifest"

# Install the CLIs as real executables in $PREFIX/bin (standard FHS layout).
# Each self-locates its library root at $bindir/../lib/bebash, so no symlink hop
# into the payload is needed. `rm -f` first so a prior install's symlink (which
# now dangles, since its payload-bin target was just cleared) is replaced rather
# than written through.
__bebash_install_mkdir_parent "$BEBASH_INSTALL_BIN_BEBASH"
rm -f -- "$BEBASH_INSTALL_BIN_BEBASH"
cp -- "$repo_root/bin/bebash" "$BEBASH_INSTALL_BIN_BEBASH"
chmod 0755 -- "$BEBASH_INSTALL_BIN_BEBASH"
__bebash_install_record "$BEBASH_INSTALL_BIN_BEBASH" "$tmp_manifest"

__bebash_install_mkdir_parent "$BEBASH_INSTALL_BIN_DOTS"
rm -f -- "$BEBASH_INSTALL_BIN_DOTS"
cp -- "$repo_root/bin/dots" "$BEBASH_INSTALL_BIN_DOTS"
chmod 0755 -- "$BEBASH_INSTALL_BIN_DOTS"
__bebash_install_record "$BEBASH_INSTALL_BIN_DOTS" "$tmp_manifest"

__bebash_install_mkdir_parent "$BEBASH_INSTALL_COMPLETION"
cp -- "$repo_root/completions/bebash.bash" "$BEBASH_INSTALL_COMPLETION"
__bebash_install_record "$BEBASH_INSTALL_COMPLETION" "$tmp_manifest"

if [[ -r "$repo_root/man/bebash.1" ]]; then
  __bebash_install_mkdir_parent "$BEBASH_INSTALL_MANPAGE"
  cp -- "$repo_root/man/bebash.1" "$BEBASH_INSTALL_MANPAGE"
  __bebash_install_record "$BEBASH_INSTALL_MANPAGE" "$tmp_manifest"
elif command -v scdoc >/dev/null 2>&1; then
  __bebash_install_mkdir_parent "$BEBASH_INSTALL_MANPAGE"
  scdoc <"$repo_root/man/bebash.1.scd" >"$BEBASH_INSTALL_MANPAGE"
  __bebash_install_record "$BEBASH_INSTALL_MANPAGE" "$tmp_manifest"
else
  printf 'bebash: warning: man/bebash.1 missing and scdoc unavailable; skipping man page\n' >&2
fi

__bebash_install_write_bashrc_block "$BEBASH_INSTALL_APP_ROOT/init.bash" "$BEBASH_INSTALL_BASHRC"

__bebash_install_sort_manifest "$tmp_manifest"
__bebash_install_validate_manifest "$tmp_manifest"
__bebash_install_remove_stale "$BEBASH_INSTALL_MANIFEST" "$tmp_manifest"
mv -- "$tmp_manifest" "$BEBASH_INSTALL_MANIFEST"
trap - EXIT INT TERM

printf 'bebash installed\n' >&2
printf '  payload: %s\n' "$BEBASH_INSTALL_APP_ROOT" >&2
printf '  cli: %s\n' "$BEBASH_INSTALL_BIN_BEBASH" >&2
printf '  dots: %s\n' "$BEBASH_INSTALL_BIN_DOTS" >&2
printf '  manifest: %s\n' "$BEBASH_INSTALL_MANIFEST" >&2
printf 'Open a new interactive shell or source %s.\n' "$BEBASH_INSTALL_BASHRC" >&2
