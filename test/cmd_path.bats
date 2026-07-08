setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "path prints keys in contract order" {
  run_bebash path
  [ "$status" -eq 0 ]
  [ "${lines[0]%%=*}" = "payload" ]
  [ "${lines[1]%%=*}" = "config" ]
  [ "${lines[2]%%=*}" = "data" ]
  [ "${lines[3]%%=*}" = "log" ]
  [ "${lines[4]%%=*}" = "manifest" ]
  [ "${lines[5]%%=*}" = "completion" ]
  [ "${lines[6]%%=*}" = "man" ]
}

@test "path --json is parseable and escapes spaces" {
  run_bebash path --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.payload and .config and .data and .log and .manifest and .completion and .man' >/dev/null
  printf '%s\n' "$output" | jq -e '.config | contains("config home")' >/dev/null
  printf '%s\n' "$output" | jq -e '.data | contains("data")' >/dev/null
}
