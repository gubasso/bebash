setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/log.bash
  source lib/ui.bash
  source lib/helpers.bash
  source functions/git-branch-gone.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "git-branch-gone help" {
  run git-branch-gone -h
  assert_success
  assert_output --partial 'usage:'
}

@test "git-branch-gone noninteractive without yes returns 2" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  fetch) exit 0 ;;
  for-each-ref) printf ' \told\t[gone]\n' ;;
esac
EOS
  chmod +x "$bindir/git"
  run git-branch-gone
  assert_failure 2
}

@test "git-branch-gone deletes with yes" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
case "$1" in
  fetch) exit 0 ;;
  for-each-ref) printf ' \told\t[gone]\n' ;;
  branch) printf '%s\n' "$*" >>"$GIT_CALLS" ;;
esac
EOS
  chmod +x "$bindir/git"
  export GIT_CALLS="$bindir/calls"
  run git-branch-gone --yes
  assert_success
  assert_file_contains "$GIT_CALLS" 'branch -d -- old'
}
