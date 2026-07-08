setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "path prints keys in contract order" {
  run_bebash path
  [ "$status" -eq 0 ]
  [ "${lines[0]%%=*}" = "payload" ]
  [ "${lines[1]%%=*}" = "overlay" ]
  [ "${lines[2]%%=*}" = "log" ]
  [ "${lines[3]%%=*}" = "manifest" ]
  [ "${lines[4]%%=*}" = "completion" ]
  [ "${lines[5]%%=*}" = "man" ]
}

@test "path --json is parseable and escapes spaces" {
  run_bebash path --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.payload and .overlay and .log and .manifest and .completion and .man' >/dev/null
  printf '%s\n' "$output" | jq -e '.overlay | contains("config home")' >/dev/null
}
