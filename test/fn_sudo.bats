setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/functions/sudo.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "sudo help" {
  run sudo -h
  assert_success
  assert_output --partial 'usage:'
}

@test "sudo validates before command" {
  cat >"$bindir/sudo" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SUDO_CALLS"
EOS
  chmod +x "$bindir/sudo"
  export SUDO_CALLS="$bindir/calls"
  run sudo true
  assert_success
  run grep -Fx -- '-v' "$SUDO_CALLS"
  assert_success
  run grep -Fx -- 'true' "$SUDO_CALLS"
  assert_success
}
