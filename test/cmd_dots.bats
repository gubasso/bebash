setup() {
  load 'test_helper/common-setup'
  _common_setup

  REPO_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
  # Keep repository resolution hermetic: no ambient DOTFILES / BEBASH_DOTFILES_DIR.
  unset DOTFILES BEBASH_DOTFILES_DIR
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$SANDBOX/config"
  export XDG_DATA_HOME="$SANDBOX/data"
  export XDG_STATE_HOME="$SANDBOX/state"
  export BEBASH_LIB="$REPO_ROOT"
  export PATH="$SANDBOX/bin:$REPO_ROOT/bin:$PATH"
  mkdir -p "$HOME" "$SANDBOX/bin" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"

  cat >"$SANDBOX/bin/git" <<'EOS'
#!/usr/bin/env bash
if [[ $1 == -C && $3 == rev-parse && $4 == --git-dir ]]; then
  printf '%s\n' "$2/.git"
  exit 0
fi
if [[ $1 == -C && $3 == ls-files ]]; then
  exit 0
fi
exit 1
EOS
  cat >"$SANDBOX/bin/stow" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STOW_LOG"
EOS
  chmod +x "$SANDBOX/bin/git" "$SANDBOX/bin/stow"
}

make_repo() {
  DOTS_REPO="$SANDBOX/repo"
  mkdir -p "$DOTS_REPO/.git" "$DOTS_REPO/alpha" "$DOTS_REPO/beta"
  export DOTS_REPO
  export STOW_LOG="$SANDBOX/stow.log"
}

@test "dots help and version exit 0" {
  run "$REPO_ROOT/bin/dots" --help
  assert_success
  assert_output --partial 'usage:'

  run "$REPO_ROOT/bin/dots" --version
  assert_success
  assert_output 'dots version 1.2.0'
}

@test "dots requires an explicit repository" {
  run "$REPO_ROOT/bin/dots" --list
  assert_failure 2
  assert_output --partial 'repository is not configured'
}

@test "dots list prints package names on stdout" {
  make_repo

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --list
  assert_success
  assert_output --partial 'alpha'
  assert_output --partial 'beta'
}

@test "dots resolves repository from DOTFILES env var" {
  make_repo

  DOTFILES="$DOTS_REPO" run "$REPO_ROOT/bin/dots" --list
  assert_success
  assert_output --partial 'alpha'
  assert_output --partial 'beta'
}

@test "dots resolves repository from BEBASH_DOTFILES_DIR env var" {
  make_repo

  BEBASH_DOTFILES_DIR="$DOTS_REPO" run "$REPO_ROOT/bin/dots" --list
  assert_success
  assert_output --partial 'alpha'
  assert_output --partial 'beta'
}

@test "dots stows selected package with explicit dir" {
  make_repo
  printf 'body\n' >"$DOTS_REPO/alpha/file"

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --yes --no-hooks alpha
  assert_success
  command grep -F -- "--dir=$DOTS_REPO -S alpha" "$STOW_LOG"
}

@test "dots dry-run preview reports stale symlinks that will be removed" {
  make_repo
  mkdir -p "$DOTS_REPO/alpha"
  printf 'body\n' >"$DOTS_REPO/alpha/file"
  # A broken symlink in the target that points into the package dir is "stale".
  command ln -s "$DOTS_REPO/alpha/gone" "$HOME/stale-link"

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run --no-hooks alpha
  assert_success
  assert_output --partial '1 stale'
  assert_output --partial '[stale] stale-link'
}

@test "dots hook environment is exported" {
  make_repo
  mkdir -p "$DOTS_REPO/alpha/.hooks"
  cat >"$DOTS_REPO/alpha/.hooks/pre-stow" <<'EOS'
#!/usr/bin/env bash
printf '%s|%s|%s|%s\n' "$DOTS_PACKAGE" "$DOTS_ACTION" "$DOTS_TARGET" "$DOTS_REPO" >"$HOOK_LOG"
EOS
  chmod +x "$DOTS_REPO/alpha/.hooks/pre-stow"
  export HOOK_LOG="$SANDBOX/hook.log"

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --yes alpha
  assert_success
  assert_file_contains "$HOOK_LOG" "alpha|stow|$HOME|$DOTS_REPO"
}
