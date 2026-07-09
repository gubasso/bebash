#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Report the failing command and line instead of a bare non-zero exit, and make
# clear that nothing was finalized (the manifest is only moved into place at the
# very end). errtrace (set -E) propagates this trap into the helper functions.
__bebash_install_on_err() {
  local ec=$? line=${1:-?}
  printf 'bebash: install failed (exit %s) at line %s: %s\n' "$ec" "$line" "${BASH_COMMAND:-?}" >&2
  printf 'bebash: nothing was finalized; a previous install (if any) is unchanged.\n' >&2
}
trap '__bebash_install_on_err "$LINENO"' ERR

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

# Remove files recorded by a prior install that this install no longer produces.
# Lenient by design: an old manifest may predate this version and list paths we
# no longer manage (e.g. a command extracted into its own project). We only
# *delete* paths inside the current whitelist; anything outside it is left in
# place with a note rather than aborting, so cross-version upgrades self-heal
# instead of failing closed. (The whitelist still guards every `rm`.)
__bebash_install_remove_stale() {
  local old_manifest=$1 new_manifest=$2 stale removed=0
  [[ -e $old_manifest ]] || return 0
  while IFS= read -r stale; do
    [[ -n $stale ]] || continue
    if [[ $stale != /* ]] || ! __bebash_install_path_allowed "$stale"; then
      printf 'bebash: note: leaving a path from a previous install in place (no longer managed): %s\n' "$stale" >&2
      continue
    fi
    [[ -e $stale || -L $stale ]] || continue
    rm -f -- "$stale"
    removed=$((removed + 1))
  done < <(comm -23 "$old_manifest" "$new_manifest")
  __bebash_install_prune_empty_dirs
  ((removed == 0)) || printf 'bebash: removed %d stale file(s) from a previous install\n' "$removed" >&2
}

# Close the orphan blind spot: the app root is fully installer-owned, so any file
# under it that the fresh manifest does not list is a leftover from an older
# layout (e.g. a top-level payload file that a past version shipped and this one
# dropped, or a file a buggy older installer failed to record). Remove it,
# whitelist-guarded, so upgrades never accumulate cruft the manifest can't reap.
__bebash_install_reconcile_payload() {
  local new_manifest=$1 path removed=0
  [[ -d $BEBASH_INSTALL_APP_ROOT ]] || return 0
  while IFS= read -r path; do
    [[ -n $path ]] || continue
    grep -qFx -- "$path" "$new_manifest" && continue
    __bebash_install_path_allowed "$path" || continue
    printf 'bebash: removing orphaned payload file: %s\n' "$path" >&2
    rm -f -- "$path"
    removed=$((removed + 1))
  done < <(find "$BEBASH_INSTALL_APP_ROOT" \( -type f -o -type l \) | LC_ALL=C sort)
  ((removed == 0)) || printf 'bebash: removed %d orphaned payload file(s)\n' "$removed" >&2
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

# Install the CLI as a real executable in $PREFIX/bin (standard FHS layout).
# It self-locates its library root at $bindir/../lib/bebash, so no symlink hop
# into the payload is needed. `rm -f` first so a prior install's symlink (which
# now dangles, since its payload-bin target was just cleared) is replaced rather
# than written through.
__bebash_install_mkdir_parent "$BEBASH_INSTALL_BIN_BEBASH"
rm -f -- "$BEBASH_INSTALL_BIN_BEBASH"
cp -- "$repo_root/bin/bebash" "$BEBASH_INSTALL_BIN_BEBASH"
chmod 0755 -- "$BEBASH_INSTALL_BIN_BEBASH"
__bebash_install_record "$BEBASH_INSTALL_BIN_BEBASH" "$tmp_manifest"

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
__bebash_install_reconcile_payload "$tmp_manifest"
__bebash_install_remove_stale "$BEBASH_INSTALL_MANIFEST" "$tmp_manifest"
file_count=$(wc -l <"$tmp_manifest")
mv -- "$tmp_manifest" "$BEBASH_INSTALL_MANIFEST"
trap - EXIT INT TERM ERR

printf 'bebash installed\n' >&2
printf '  payload:  %s (%s files)\n' "$BEBASH_INSTALL_APP_ROOT" "$file_count" >&2
printf '  cli:      %s\n' "$BEBASH_INSTALL_BIN_BEBASH" >&2
printf '  manifest: %s\n' "$BEBASH_INSTALL_MANIFEST" >&2
printf 'Open a new interactive shell or source %s.\n' "$BEBASH_INSTALL_BASHRC" >&2
