setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source functions/git-emails.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "git-emails help" {
  run git-emails -h
  assert_success
  assert_output --partial 'usage:'
}

@test "git-emails lists unique history emails" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
printf 'b@example.test\na@example.test\na@example.test\n'
EOS
  chmod +x "$bindir/git"
  run git-emails
  assert_success
  assert_output $'a@example.test\nb@example.test'
}
