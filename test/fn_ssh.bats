setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/functions/ssh.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "ssh help" {
  run ssh -h
  assert_success
  assert_output --partial 'usage:'
}

@test "ssh uses kitten inside kitty" {
  cat >"$bindir/kitten" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*"
EOS
  chmod +x "$bindir/kitten"
  KITTY_WINDOW_ID=1 run ssh host
  assert_success
  assert_output 'ssh host'
}
