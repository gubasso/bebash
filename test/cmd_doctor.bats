setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "doctor json emits checks and fails before overlay exists" {
  run_bebash doctor --json
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | jq -e 'type == "array" and (.[] | select(.check == "overlay" and .status == "fail"))' >/dev/null
}

@test "doctor succeeds when required checks pass" {
  run_bebash init-user
  [ "$status" -eq 0 ]

  run_bebash doctor --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e 'type == "array" and (.[] | select(.check == "bash"))' >/dev/null
}
