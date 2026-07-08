setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source lib/functions/fdclip.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "fdclip help" {
  run fdclip -h
  assert_success
  assert_output --partial 'usage:'
}

@test "fdclip renders and copies files" {
  cat >"$bindir/fd" <<'EOS'
#!/usr/bin/env bash
printf 'a.txt\0'
EOS
  cat >"$bindir/bat" <<'EOS'
#!/usr/bin/env bash
printf 'rendered\n'
EOS
  cat >"$bindir/xclip" <<'EOS'
#!/usr/bin/env bash
cat >"$XCLIP_OUT"
EOS
  chmod +x "$bindir/fd" "$bindir/bat" "$bindir/xclip"
  export XCLIP_OUT="$bindir/clip"
  run fdclip
  assert_success
  assert_output 'a.txt'
  assert_file_contains "$XCLIP_OUT" 'rendered'
}
