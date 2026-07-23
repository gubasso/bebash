# bats test_tags=integration

setup() {
  load 'test_helper/common-setup'
  _common_setup

  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home"
  export PREFIX="$SANDBOX/prefix"
  export XDG_CONFIG_HOME="$SANDBOX/config"
  export XDG_DATA_HOME="$SANDBOX/data"
  export XDG_STATE_HOME="$SANDBOX/state"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME/bebash"
  printf 'custom line\n' >"$HOME/.bashrc"
  printf '# user config\n' >"$XDG_CONFIG_HOME/bebash/config.bash"
}

teardown() {
  rm -rf "$SANDBOX"
}

run_install() {
  run "$REPO_ROOT/install.sh"
}

run_uninstall() {
  run "$REPO_ROOT/uninstall.sh"
}

# Echo the first installed locale whose collation is dictionary-style (sorts
# lowercase 'a' before uppercase 'B'), which is where a byte-sorted manifest and
# an unqualified `comm` disagree. Returns non-zero if only C/POSIX exist.
find_dict_locale() {
  local loc
  while IFS= read -r loc; do
    case $loc in C | C.* | POSIX) continue ;; esac
    [[ $(printf 'B\na\n' | LC_ALL="$loc" sort 2>/dev/null | head -n1) == a ]] || continue
    printf '%s\n' "$loc"
    return 0
  done < <(locale -a 2>/dev/null)
  return 1
}

@test "install creates payload cli completion man and manifest" {
  run_install
  assert_success

  assert_file_exists "$PREFIX/lib/bebash/init.bash"
  assert_file_exists "$PREFIX/lib/bebash/lib/loader.bash"
  assert_file_exists "$PREFIX/lib/bebash/lib/core.bash"
  assert_dir_exists "$PREFIX/lib/bebash/libexec/commands"
  assert_dir_exists "$PREFIX/lib/bebash/functions"
  assert_dir_exists "$PREFIX/lib/bebash/rc.d"
  assert_file_exists "$PREFIX/lib/bebash/rc.d/15-commands-path.bash"
  assert_file_exists "$PREFIX/lib/bebash/rc.d/20-navigation.bash"
  [[ "$(find "$PREFIX/lib/bebash/rc.d" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort | tr '\n' ' ')" = "15-commands-path.bash 20-navigation.bash " ]]
  assert_dir_exists "$PREFIX/lib/bebash/templates"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/commands"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/functions"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/rc.d"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/templates"
  # The CLI is installed as a real executable in $PREFIX/bin (not a symlink), and
  # the payload no longer carries a bin/ subdir.
  assert_file_executable "$PREFIX/bin/bebash"
  [[ ! -L "$PREFIX/bin/bebash" ]]
  assert_dir_not_exists "$PREFIX/lib/bebash/bin"
  assert_file_exists "$XDG_DATA_HOME/bash-completion/completions/bebash"
  if [[ -e "$REPO_ROOT/man/bebash.1" ]] || command -v scdoc >/dev/null 2>&1; then
    assert_file_exists "$XDG_DATA_HOME/man/man1/bebash.1"
  fi
  assert_file_exists "$XDG_STATE_HOME/bebash/install-manifest"
}

@test "install replaces a dangling CLI symlink from the old layout" {
  # Model an upgrade from the old symlink layout: $PREFIX/bin/bebash is a symlink
  # into the payload bin/, which the new installer clears — leaving it dangling.
  # cp must not try to write through it.
  mkdir -p "$PREFIX/bin"
  ln -s "$PREFIX/lib/bebash/bin/bebash" "$PREFIX/bin/bebash"

  run_install
  assert_success
  assert_file_executable "$PREFIX/bin/bebash"
  [[ ! -L "$PREFIX/bin/bebash" ]]
}

@test "installed CLI self-locates its library root with BEBASH_LIB unset" {
  run_install
  assert_success

  # A real bin in $PREFIX/bin must resolve the payload at $PREFIX/lib/bebash
  # from its own path (installed-layout probe), with no BEBASH_LIB in the env.
  run env -u BEBASH_LIB "$PREFIX/bin/bebash" path
  assert_success
  assert_output --partial "payload=$PREFIX/lib/bebash"
}

@test "repo-tree CLI self-locates its library root with BEBASH_LIB unset" {
  # The same script run from the repo working tree must fall back to the
  # repo-layout probe ($bindir/..).
  run env -u BEBASH_LIB "$REPO_ROOT/bin/bebash" path
  assert_success
  assert_output --partial "payload=$REPO_ROOT"
}

@test "manifest is absolute sorted unique whitelisted and excludes bashrc" {
  run_install
  assert_success

  manifest="$XDG_STATE_HOME/bebash/install-manifest"
  diff -u "$manifest" <(LC_ALL=C sort -u "$manifest")
  while IFS= read -r path; do
    [[ $path == /* ]]
    [[ $path != "$HOME/.bashrc" ]]
    [[ $path != "$HOME/.bashrc.bebash.bak" ]]
    case "$path" in
    "$PREFIX/lib/bebash" | "$PREFIX/lib/bebash"/*) ;;
    "$PREFIX/bin/bebash") ;;
    "$PREFIX/bin/bebash-cmd") ;;
    "$XDG_DATA_HOME/bash-completion/completions/bebash") ;;
    "$XDG_DATA_HOME/man/man1/bebash.1") ;;
    "$XDG_STATE_HOME/bebash" | "$XDG_STATE_HOME/bebash"/*) ;;
    *) fail "manifest path outside whitelist: $path" ;;
    esac
  done <"$manifest"
}

@test "install never touches the user's shell rc" {
  # One writer per file: the installer owns only its payload + state, never the
  # user-authored ~/.bashrc. Shell integration is a documented manual step, so a
  # re-install must leave the rc byte-identical and create no backup file.
  cp "$HOME/.bashrc" "$SANDBOX/bashrc.before"
  run_install
  assert_success
  run_install
  assert_success

  cmp "$SANDBOX/bashrc.before" "$HOME/.bashrc"
  assert_file_contains "$HOME/.bashrc" 'custom line'
  assert_file_not_contains "$HOME/.bashrc" '# >>> bebash >>>'
  assert_file_not_exists "$HOME/.bashrc.bebash.bak"
}

@test "install leaves a symlinked shell rc and its target untouched" {
  # Model a stow/dotfiles or Home Manager setup: ~/.bashrc is a symlink to a
  # tracked (possibly read-only /nix/store) file. The installer must neither
  # follow nor rewrite it — that would clobber a managed file or fail on a
  # read-only target.
  mkdir -p "$SANDBOX/dotfiles"
  printf 'custom line\n' >"$SANDBOX/dotfiles/.bashrc"
  rm -f "$HOME/.bashrc"
  ln -s "$SANDBOX/dotfiles/.bashrc" "$HOME/.bashrc"
  cp "$SANDBOX/dotfiles/.bashrc" "$SANDBOX/dotfiles-bashrc.before"

  run_install
  assert_success

  assert_symlink_to "$SANDBOX/dotfiles/.bashrc" "$HOME/.bashrc"
  cmp "$SANDBOX/dotfiles-bashrc.before" "$SANDBOX/dotfiles/.bashrc"
  assert_file_not_contains "$SANDBOX/dotfiles/.bashrc" '# >>> bebash >>>'
  assert_file_not_exists "$HOME/.bashrc.bebash.bak"
}

@test "uninstall leaves a symlinked shell rc and its target untouched" {
  mkdir -p "$SANDBOX/dotfiles"
  printf 'custom line\n' >"$SANDBOX/dotfiles/.bashrc"
  rm -f "$HOME/.bashrc"
  ln -s "$SANDBOX/dotfiles/.bashrc" "$HOME/.bashrc"
  cp "$SANDBOX/dotfiles/.bashrc" "$SANDBOX/dotfiles-bashrc.before"

  run_install
  assert_success
  run_uninstall
  assert_success

  assert_symlink_to "$SANDBOX/dotfiles/.bashrc" "$HOME/.bashrc"
  cmp "$SANDBOX/dotfiles-bashrc.before" "$SANDBOX/dotfiles/.bashrc"
  assert_file_contains "$SANDBOX/dotfiles/.bashrc" 'custom line'
}

@test "reinstall prunes stale manifest file" {
  run_install
  assert_success

  stale="$PREFIX/lib/bebash/lib/stale.bash"
  printf 'stale\n' >"$stale"
  printf '%s\n' "$stale" >>"$XDG_STATE_HOME/bebash/install-manifest"
  LC_ALL=C sort -u "$XDG_STATE_HOME/bebash/install-manifest" -o "$XDG_STATE_HOME/bebash/install-manifest"

  run_install
  assert_success
  assert_file_not_exists "$stale"
  ! grep -Fqx -- "$stale" "$XDG_STATE_HOME/bebash/install-manifest"
}

@test "reinstall prunes stale files when comm runs under a dictionary locale" {
  local dict
  dict=$(find_dict_locale) || skip "no dictionary-collating locale installed"

  run_install
  assert_success

  # install.sh writes the manifest with `LC_ALL=C sort`. Under a dictionary
  # locale an unqualified `comm` rejects that byte-sorted file as "not in sorted
  # order" and skips pruning; forcing `LC_ALL=C comm` keeps the diff correct. The
  # stale entry lives under the state dir (whitelisted, but outside the payload
  # root the reconciler sweeps first) so only the manifest diff can prune it.
  stale="$XDG_STATE_HOME/bebash/stale-artifact"
  printf 'stale\n' >"$stale"
  manifest="$XDG_STATE_HOME/bebash/install-manifest"
  printf '%s\n' "$stale" >>"$manifest"
  LC_ALL=C sort -u -- "$manifest" -o "$manifest"

  LC_ALL="$dict" run_install
  assert_success
  refute_output --partial 'not in sorted order'
  assert_file_not_exists "$stale"
  ! grep -Fqx -- "$stale" "$manifest"
}

@test "reinstall self-heals when the prior manifest lists an unmanaged path" {
  run_install
  assert_success

  # Model an upgrade where a previously-installed command was dropped from this
  # version: its path lingers in the old manifest but is no longer whitelisted.
  # The install must not abort (the old failure mode); the unmanaged path is left
  # in place (outside the whitelist, never force-removed) and omitted from the
  # freshly written manifest.
  legacy="$PREFIX/bin/legacy-tool"
  printf '#!/bin/sh\n' >"$legacy"
  printf '%s\n' "$legacy" >>"$XDG_STATE_HOME/bebash/install-manifest"
  LC_ALL=C sort -u "$XDG_STATE_HOME/bebash/install-manifest" -o "$XDG_STATE_HOME/bebash/install-manifest"

  run_install
  assert_success
  assert_output --partial 'no longer managed'
  assert_file_exists "$legacy"
  ! grep -Fqx -- "$legacy" "$XDG_STATE_HOME/bebash/install-manifest"
}

@test "reinstall reaps an orphaned payload file absent from the manifest" {
  run_install
  assert_success

  # A leftover under the installer-owned app root that no manifest records (e.g.
  # a top-level payload file a past version shipped, or a buggy older installer
  # failed to record). The hard-wipe misses arbitrary top-level files, so the
  # orphan reconciler must reap it.
  orphan="$PREFIX/lib/bebash/legacy-orphan.bash"
  printf 'orphan\n' >"$orphan"

  run_install
  assert_success
  assert_output --partial 'orphaned payload file'
  assert_file_not_exists "$orphan"
}

@test "reinstall prunes old empty layout dirs" {
  run_install
  assert_success

  mkdir -p \
    "$PREFIX/lib/bebash/lib/commands" \
    "$PREFIX/lib/bebash/lib/functions" \
    "$PREFIX/lib/bebash/lib/rc.d" \
    "$PREFIX/lib/bebash/lib/templates"

  run_install
  assert_success
  assert_file_not_exists "$PREFIX/lib/bebash/lib/commands"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/functions"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/rc.d"
  assert_file_not_exists "$PREFIX/lib/bebash/lib/templates"
}

@test "uninstall removes manifest set preserves overlay and leaves bashrc untouched" {
  run_install
  assert_success
  cp "$HOME/.bashrc" "$SANDBOX/bashrc.before"
  mapfile -t installed <"$XDG_STATE_HOME/bebash/install-manifest"

  run_uninstall
  assert_success

  for path in "${installed[@]}"; do
    [[ ! -e $path ]]
  done
  assert_file_not_exists "$XDG_STATE_HOME/bebash/install-manifest"
  cmp "$SANDBOX/bashrc.before" "$HOME/.bashrc"
  assert_file_contains "$HOME/.bashrc" 'custom line'
  assert_file_not_contains "$HOME/.bashrc" '# >>> bebash >>>'
  assert_file_exists "$XDG_CONFIG_HOME/bebash/config.bash"
  assert_file_not_exists "$XDG_DATA_HOME/bebash/functions"
}

@test "uninstall refuses out-of-whitelist manifest without mutating files or bashrc" {
  run_install
  assert_success

  outside="$SANDBOX/outside-file"
  printf 'do not delete\n' >"$outside"
  printf '%s\n' "$outside" >>"$XDG_STATE_HOME/bebash/install-manifest"
  cp "$HOME/.bashrc" "$SANDBOX/bashrc.before"

  run_uninstall
  assert_failure
  assert_file_exists "$outside"
  cmp "$SANDBOX/bashrc.before" "$HOME/.bashrc"
  assert_file_not_contains "$HOME/.bashrc" '# >>> bebash >>>'
}

@test "uninstall refuses traversal manifest path that escapes the whitelist" {
  run_install
  assert_success

  outside="$SANDBOX/traversal-target"
  printf 'do not delete\n' >"$outside"
  # A `..`-laden path that string-prefixes the app root but resolves outside it.
  printf '%s\n' "$PREFIX/lib/bebash/../../traversal-target" \
    >>"$XDG_STATE_HOME/bebash/install-manifest"
  cp "$HOME/.bashrc" "$SANDBOX/bashrc.before"

  run_uninstall
  assert_failure
  assert_file_exists "$outside"
  cmp "$SANDBOX/bashrc.before" "$HOME/.bashrc"
  assert_file_not_contains "$HOME/.bashrc" '# >>> bebash >>>'
}
