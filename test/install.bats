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

@test "install creates payload cli completion man and manifest" {
  run_install
  assert_success

  assert_file_executable "$PREFIX/lib/bebash/bin/bebash"
  assert_file_exists "$PREFIX/lib/bebash/init.bash"
  assert_file_exists "$PREFIX/lib/bebash/lib/loader.bash"
  assert_symlink_to "$PREFIX/lib/bebash/bin/bebash" "$PREFIX/bin/bebash"
  assert_file_exists "$XDG_DATA_HOME/bash-completion/completions/bebash"
  if [[ -e "$REPO_ROOT/man/bebash.1" ]] || command -v scdoc >/dev/null 2>&1; then
    assert_file_exists "$XDG_DATA_HOME/man/man1/bebash.1"
  fi
  assert_file_exists "$XDG_STATE_HOME/bebash/install-manifest"
}

@test "manifest is absolute sorted unique whitelisted and excludes bashrc" {
  run_install
  assert_success

  manifest="$XDG_STATE_HOME/bebash/install-manifest"
  diff -u "$manifest" <(LC_ALL=C sort -u "$manifest")
  while IFS= read -r path; do
    [[ "$path" == /* ]]
    [[ "$path" != "$HOME/.bashrc" ]]
    [[ "$path" != "$HOME/.bashrc.bebash.bak" ]]
    case "$path" in
      "$PREFIX/lib/bebash"|"$PREFIX/lib/bebash"/*) ;;
      "$PREFIX/bin/bebash") ;;
      "$XDG_DATA_HOME/bash-completion/completions/bebash") ;;
      "$XDG_DATA_HOME/man/man1/bebash.1") ;;
      "$XDG_STATE_HOME/bebash"|"$XDG_STATE_HOME/bebash"/*) ;;
      *) fail "manifest path outside whitelist: $path" ;;
    esac
  done <"$manifest"
}

@test "bashrc block is idempotent and references resolved payload init" {
  run_install
  assert_success
  run_install
  assert_success

  assert_file_contains "$HOME/.bashrc" 'custom line'
  assert_file_contains "$HOME/.bashrc" '# >>> bebash >>>'
  assert_file_contains "$HOME/.bashrc" "$PREFIX/lib/bebash/init.bash"
  [[ $(grep -c '^# >>> bebash >>>$' "$HOME/.bashrc") -eq 1 ]]
  [[ $(grep -c '^# <<< bebash <<<$' "$HOME/.bashrc") -eq 1 ]]
  assert_file_contains "$HOME/.bashrc.bebash.bak" 'custom line'
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

@test "uninstall removes manifest set strips block and preserves overlay" {
  run_install
  assert_success
  mapfile -t installed <"$XDG_STATE_HOME/bebash/install-manifest"

  run_uninstall
  assert_success

  for path in "${installed[@]}"; do
    [[ ! -e "$path" ]]
  done
  assert_file_not_exists "$XDG_STATE_HOME/bebash/install-manifest"
  assert_file_not_contains "$HOME/.bashrc" '# >>> bebash >>>'
  assert_file_contains "$HOME/.bashrc" 'custom line'
  assert_file_exists "$XDG_CONFIG_HOME/bebash/config.bash"
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
  assert_file_contains "$HOME/.bashrc" '# >>> bebash >>>'
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
  assert_file_contains "$HOME/.bashrc" '# >>> bebash >>>'
}
