setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/log.bash
  source lib/ui.bash
  source lib/helpers.bash
  source functions/git-branch-sync.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

_stub_git_gone() {
  # Fake git: one non-current local branch "old" whose upstream is gone.
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  for-each-ref)
    case "$*" in
    *refs/heads*) printf ' \told\torigin/old\torigin\t[gone]\n' ;;
    esac
    ;;
  branch) printf '%s\n' "$*" >>"$GIT_CALLS" ;;
esac
exit 0
EOS
  chmod +x "$bindir/git"
  export GIT_CALLS="$bindir/calls"
}

_real_fixture() {
  # Bare remote + worktree covering every classification bucket.
  bare="$BATS_TEST_TMPDIR/bare.git"
  work="$BATS_TEST_TMPDIR/work"
  git init -q --bare "$bare"
  git init -q -b main "$work"
  cd "$work" || return 1
  git config user.email test@test
  git config user.name test
  git commit -q --allow-empty -m one
  git remote add origin "$bare"
  git push -qu origin main # in sync
  git switch -qc develop
  git push -qu origin develop
  git commit -q --allow-empty -m two # ahead 1
  git switch -qc feature-x main
  git push -qu origin feature-x
  git commit -q --allow-empty -m three
  git push -q origin feature-x
  git reset -q --hard HEAD~1 # behind 1
  git branch wip-idea main   # only local, no upstream
  git branch old-work main
  git push -qu origin old-work
  git push -q origin --delete old-work                # [gone] after prune
  git push -q origin main:refs/heads/initial-implementation # only remote
  git switch -q main
}

@test "git-branch-sync help" {
  run git-branch-sync -h
  assert_success
  assert_output --partial 'usage:'
}

@test "git-branch-sync unknown option returns 2" {
  run git-branch-sync --bogus
  assert_failure 2
}

@test "git-branch-sync --gone noninteractive without yes returns 2" {
  _stub_git_gone
  run git-branch-sync --gone
  assert_failure 2
}

@test "git-branch-sync --gone deletes with yes" {
  _stub_git_gone
  run git-branch-sync --gone --yes
  assert_success
  assert_file_contains "$GIT_CALLS" 'branch -d -- old'
}

@test "git-branch-sync --gone --force uses -D" {
  _stub_git_gone
  run git-branch-sync --gone --force --yes
  assert_success
  assert_file_contains "$GIT_CALLS" 'branch -D -- old'
}

@test "git-branch-sync --gone never deletes the current branch" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  for-each-ref)
    case "$*" in
    *refs/heads*) printf '*\tmain\torigin/main\torigin\t[gone]\n' ;;
    esac
    ;;
  branch) printf '%s\n' "$*" >>"$GIT_CALLS" ;;
esac
exit 0
EOS
  chmod +x "$bindir/git"
  export GIT_CALLS="$bindir/calls"
  run git-branch-sync --gone --yes
  assert_success
  assert_output --partial 'switch away'
  assert_file_not_exist "$GIT_CALLS"
}

@test "git-branch-sync unknown remote returns 2" {
  _real_fixture
  run git-branch-sync --dry-run -r nope
  assert_failure 2
}

@test "git-branch-sync --dry-run classifies and plans" {
  _real_fixture
  run git-branch-sync --dry-run
  assert_success

  assert_output --partial '== both (3) =='
  assert_output --partial 'in sync'
  assert_output --partial 'develop'
  assert_output --partial '↑1 ahead'
  assert_output --partial 'feature-x'
  assert_output --partial '↓1 behind'
  assert_output --partial '== only local (2) =='
  assert_output --partial 'wip-idea'
  assert_output --partial '[gone]'
  assert_output --partial '== only remote (1) =='
  assert_output --partial 'initial-implementation'

  assert_output --partial 'git push -- origin develop'
  assert_output --partial 'git fetch -- origin feature-x:feature-x'
  assert_output --partial 'git push -u -- origin wip-idea'
  assert_output --partial 'git branch --track -- initial-implementation origin/initial-implementation'
  refute_output --partial 'HEAD'
}

@test "git-branch-sync --gone --dry-run plans without deleting" {
  _real_fixture
  run git-branch-sync --gone --dry-run
  assert_success
  assert_output --partial 'git branch -d -- old-work'
  run git -C "$work" branch --list old-work
  assert_output --partial 'old-work'
}

@test "git-branch-sync --gone --yes deletes gone branch in a real repo" {
  _real_fixture
  run git-branch-sync --gone --yes
  assert_success
  run git -C "$work" branch --list old-work
  refute_output --partial 'old-work'
}
