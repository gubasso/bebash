setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source functions/gi.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "gi help" {
  run gi -h
  assert_success
  assert_output --partial 'usage:'
}

@test "gi fetches template" {
  cat >"$bindir/curl" <<'EOS'
#!/usr/bin/env bash
printf 'template:%s\n' "$*"
EOS
  chmod +x "$bindir/curl"
  run gi bash
  assert_success
  assert_output --partial 'bash'
}
