setup() {
  load 'test_helper/common-setup'
  _common_setup
  export BEBASH_LIB="$BATS_TEST_DIRNAME/.."
  export TMPDIR="$BEBASH_LIB/test/tmp/${BATS_TEST_NAME//[^A-Za-z0-9_]/_}"
  rm -rf -- "$TMPDIR"
  mkdir -p -- "$TMPDIR/bin"
  source lib/ui.bash
  source lib/helpers.bash
  source lib/interact.bash
}

@test "require_tty succeeds in tty mode and fails through msg in gui mode" {
  BEBASH_UI="tty"
  run interact::require_tty "tty needed"
  assert_success

  cat >"$TMPDIR/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
EOF
  chmod 0755 "$TMPDIR/bin/notify-send"
  # shellcheck disable=SC2030
  export PATH="$TMPDIR/bin:$PATH"
  # shellcheck disable=SC2030
  export NOTIFY_LOG="$TMPDIR/notify.log"

  BEBASH_UI="gui"
  run interact::require_tty "tty needed"

  assert_failure 1
  grep -F "tty needed" "$NOTIFY_LOG"
}

@test "require_gui succeeds in gui mode and fails through msg in tty mode" {
  cat >"$TMPDIR/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NOTIFY_LOG"
EOF
  chmod 0755 "$TMPDIR/bin/notify-send"
  # shellcheck disable=SC2031
  export PATH="$TMPDIR/bin:$PATH"
  # shellcheck disable=SC2031
  export NOTIFY_LOG="$TMPDIR/notify.log"

  BEBASH_UI="gui"
  run interact::require_gui "gui needed"
  assert_success

  BEBASH_UI="tty"
  run interact::require_gui "gui needed"
  assert_failure 1
  [[ "$output" == *"gui needed"* ]]
}
