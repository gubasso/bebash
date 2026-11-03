setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "version prints VERSION" {
  run_bebash version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$BEBASH_LIB/VERSION")" ]
}

@test "global --version prints VERSION" {
  run_bebash --version
  [ "$status" -eq 0 ]
  [ "$output" = "$(cat "$BEBASH_LIB/VERSION")" ]
}
