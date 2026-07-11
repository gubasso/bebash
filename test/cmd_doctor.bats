setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "doctor json emits object and fails before user roots exist" {
  run_bebash doctor --json --no-tools
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | jq -e '.ok == false and .summary.fail >= 2' >/dev/null
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "ENV003" and .severity == "fail")' >/dev/null
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "ENV004" and .severity == "fail")' >/dev/null
}

@test "doctor succeeds after init without tools" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]

  run_bebash doctor --json --no-tools --scope user
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.ok == true and (.paths.config | contains("bebash")) and (.logs | type == "array")' >/dev/null
}

@test "doctor reports function convention failures" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  cat >"$XDG_DATA_HOME/bebash/functions/bad.bash" <<'EOF'
# shellcheck shell=bash
: 'desc: bad'
other() { :; }
extra() { :; }
EOF

  run_bebash doctor --json --no-tools --scope user
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "FUNC002")' >/dev/null
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "FUNC003")' >/dev/null
}

@test "doctor reports lib guard and stale config warnings" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  mkdir -p "$XDG_CONFIG_HOME/bebash/functions"
  cat >"$XDG_DATA_HOME/bebash/lib/no_guard.bash" <<'EOF'
# shellcheck shell=bash
: 'desc: no guard'
__private() { :; }
EOF

  run_bebash doctor --json --no-tools --scope user
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "LIB002" and .severity == "fail")' >/dev/null
  printf '%s\n' "$output" | jq -e '.checks[] | select(.code == "ENV008" and .severity == "warn")' >/dev/null
}

@test "doctor logs flag and bad logs argument" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]

  run_bebash doctor --logs=1 --no-tools --scope user
  [ "$status" -eq 0 ]
  [[ "$output" == *"logs"* ]]

  run_bebash doctor --logs=bogus
  [ "$status" -eq 2 ]
}

@test "doctor help succeeds and scope user skips payload command checks" {
  run_bebash doctor -h
  [ "$status" -eq 0 ]
  [[ "$output" == usage:* ]]

  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  run_bebash doctor --json --no-tools --scope user
  [ "$status" -eq 0 ]
  ! printf '%s\n' "$output" | jq -e '.checks[] | select(.scope == "payload")' >/dev/null
}
