setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "help prints generated command list" {
  run_bebash help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: bebash"* ]]
  [[ "$output" == *"doctor"* ]]
}

@test "help unknown command exits 2" {
  run_bebash help bogus
  [ "$status" -eq 2 ]
}
