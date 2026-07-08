setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "--json stdout is parseable and contains no ansi" {
  run_bebash --json path
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e . >/dev/null
  [[ "$output" != *$'\033['* ]]
}

@test "--color never disables ansi on errors" {
  run_bebash --color never bogus
  [ "$status" -eq 2 ]
  [[ "$output" != *$'\033['* ]]
}

@test "--silent suppresses terminal ux while file log writes" {
  export BEBASH_LOG_LEVEL=error
  run_bebash --silent bogus
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  grep -q 'level=error' "$XDG_STATE_HOME/bebash/bebash.log"
}
