setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "help prints generated command list" {
  run_bebash help
  [ "$status" -eq 0 ]
  [[ "$output" == *"usage: bebash"* ]]
  [[ "$output" == *"doctor"* ]]
  [[ "$output" == *"init"* ]]
  [[ "$output" == *"man"* ]]
  local old_cmd="init""-user"
  [[ "$output" != *"$old_cmd"* ]]
}

@test "help unknown command exits 2" {
  run_bebash help bogus
  [ "$status" -eq 2 ]
}

@test "help prints init and man usage" {
  run_bebash help init
  [ "$status" -eq 0 ]
  [[ "$output" == "usage: bebash init"* ]]

  run_bebash help man
  [ "$status" -eq 0 ]
  [[ "$output" == "usage: bebash man"* ]]
}
