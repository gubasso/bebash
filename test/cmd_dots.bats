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

# ---- dependency resolution ----

make_pkg() { # make_pkg <name>: create a package dir with a file
  mkdir -p "$DOTS_REPO/$1"
  printf 'body\n' >"$DOTS_REPO/$1/file"
}

set_deps() { # set_deps <pkg> <dep>...: write the package's .hooks/depends
  local pkg=$1
  shift
  mkdir -p "$DOTS_REPO/$pkg/.hooks"
  printf '%s\n' "$@" >"$DOTS_REPO/$pkg/.hooks/depends"
}

@test "dots resolves a linear dependency chain without nameref warnings" {
  make_repo
  make_pkg gamma
  set_deps alpha beta
  set_deps beta gamma

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run alpha
  assert_success
  refute_output --partial 'circular name reference'
  refute_output --partial 'unbound variable'
  assert_output --partial 'beta'
  assert_output --partial 'gamma'
  assert_output --partial 'dependency of'
}

@test "dots resolves a diamond dependency graph" {
  make_repo
  make_pkg gamma
  make_pkg delta
  set_deps alpha beta gamma
  set_deps beta delta
  set_deps gamma delta

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run alpha
  assert_success
  refute_output --partial 'circular name reference'
  assert_output --partial 'delta'
}

@test "dots detects a dependency cycle instead of looping" {
  make_repo
  set_deps alpha beta
  set_deps beta alpha

  run timeout 10 "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run alpha
  assert_failure
  assert_output --partial 'circular dependency detected'
  refute_output --partial 'circular name reference'
}

@test "dots fails on a missing dependency without --sync" {
  make_repo
  set_deps alpha ghost

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run alpha
  assert_failure
  assert_output --partial "dependency 'ghost' not found"
}

@test "dots --sync skips a missing dependency and warns" {
  make_repo
  set_deps alpha ghost

  run "$REPO_ROOT/bin/dots" --dir "$DOTS_REPO" --dry-run --sync
  assert_success
  assert_output --partial 'skipped missing packages'
  assert_output --partial 'ghost'
}

@test "dots detects stale symlinks when the repo has a symlinked ancestor" {
  # Real repo behind a symlinked path: abs_target canonicalizes through the
  # symlink, so pkg_dir must be canonicalized too or the prefix test misses
  # the stale link (regression: symlinked-ancestor canonicalization).
  mkdir -p "$SANDBOX/store/repo/.git" "$SANDBOX/store/repo/alpha"
  printf 'body\n' >"$SANDBOX/store/repo/alpha/file"
  command ln -s store/repo "$SANDBOX/repo-link"
  export STOW_LOG="$SANDBOX/stow.log"
  command ln -s "$SANDBOX/repo-link/alpha/gone" "$HOME/stale-link"

  run "$REPO_ROOT/bin/dots" --dir "$SANDBOX/repo-link" --dry-run --no-hooks alpha
  assert_success
  assert_output --partial '1 stale'
  assert_output --partial '[stale] stale-link'
}
