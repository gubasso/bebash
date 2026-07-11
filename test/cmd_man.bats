setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "man prints plain reference" {
  run_bebash man
  [ "$status" -eq 0 ]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"init"* ]]
  [[ "$output" == *"AGENTS.md"* ]]
}

@test "man source prints scdoc markers" {
  run_bebash man --source
  [ "$status" -eq 0 ]
  [[ "$output" == *"# COMMANDS"* ]]
}

@test "man missing source exits 66" {
  mkdir -p "$TMPDIR/empty-lib/libexec/commands" "$TMPDIR/empty-lib/lib" "$TMPDIR/empty-lib/functions" "$TMPDIR/empty-lib/rc.d"
  cp "$BEBASH_LIB/lib/core.bash" "$TMPDIR/empty-lib/lib/core.bash"
  cp "$BEBASH_LIB/lib/ui.bash" "$TMPDIR/empty-lib/lib/ui.bash"
  cp "$BEBASH_LIB/lib/log.bash" "$TMPDIR/empty-lib/lib/log.bash"
  cp "$BEBASH_LIB/lib/helpers.bash" "$TMPDIR/empty-lib/lib/helpers.bash"
  cp "$BEBASH_LIB/lib/loader.bash" "$TMPDIR/empty-lib/lib/loader.bash"
  cp "$BEBASH_LIB/libexec/commands/cmd_man.bash" "$TMPDIR/empty-lib/libexec/commands/cmd_man.bash"
  cp "$BEBASH_LIB/bin/bebash" "$TMPDIR/empty-bebash"
  BEBASH_LIB="$TMPDIR/empty-lib" run "$TMPDIR/empty-bebash" man
  [ "$status" -eq 66 ]
}

@test "man bad flag exits 2" {
  run_bebash man --bad
  [ "$status" -eq 2 ]
}
