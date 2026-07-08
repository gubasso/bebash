setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source lib/functions/slug.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "slug help" {
  run slug -h
  assert_success
  assert_output --partial 'usage:'
}

@test "slug prints and copies" {
  cat >"$bindir/slugify" <<'EOS'
#!/usr/bin/env bash
printf 'hello-world\n'
EOS
  cat >"$bindir/xclip" <<'EOS'
#!/usr/bin/env bash
cat >"$XCLIP_OUT"
EOS
  chmod +x "$bindir/slugify" "$bindir/xclip"
  export XCLIP_OUT="$bindir/clip"
  run slug "Hello World"
  assert_success
  assert_output 'hello-world'
  assert_file_contains "$XCLIP_OUT" 'hello-world'
}
