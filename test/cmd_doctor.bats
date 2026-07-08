setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "doctor json emits checks and fails before user roots exist" {
  run_bebash doctor --json
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | jq -e 'type == "array" and (.[] | select(.check == "config" and .status == "fail"))' >/dev/null
  printf '%s\n' "$output" | jq -e 'type == "array" and (.[] | select(.check == "data" and .status == "fail"))' >/dev/null
}

@test "doctor succeeds when required checks pass" {
  run_bebash init-user
  [ "$status" -eq 0 ]

  run_bebash doctor --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'type == "array" and (.[] | select(.check == "bash"))' >/dev/null
}

@test "doctor warns on old config code dirs" {
  run_bebash init-user
  [ "$status" -eq 0 ]
  mkdir -p "$XDG_CONFIG_HOME/bebash/functions"

  run_bebash doctor --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.[] | select(.check == "old-config-functions" and .status == "warn")' >/dev/null
}
