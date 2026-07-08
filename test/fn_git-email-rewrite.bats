setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source functions/git-email-rewrite.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "git-email-rewrite help" {
  run git-email-rewrite -h
  assert_success
  assert_output --partial 'usage:'
}

@test "git-email-rewrite dry run prints mailmap" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
  chmod +x "$bindir/git"
  run git-email-rewrite old@example.test new@example.test "New Name"
  assert_success
  assert_output --partial 'New Name <new@example.test> <old@example.test>'
}

@test "git-email-rewrite apply refuses noninteractive without yes" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
exit 0
EOS
  chmod +x "$bindir/git"
  run git-email-rewrite --apply old@example.test new@example.test
  assert_failure 2
}
