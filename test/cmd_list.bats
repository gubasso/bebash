setup() {
  load 'cmd_helper'
  cmd_setup
  mkdir -p "$XDG_DATA_HOME/bebash/functions"
}

@test "list includes shipped gpr origin" {
  run_bebash list
  [ "$status" -eq 0 ]
  [[ "$output" == *"gpr"*"shipped"* ]]
}

@test "list data wins duplicates" {
  cat >"$XDG_DATA_HOME/bebash/functions/gpr.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: Overlay description with "quote" and \ backslash.'
gpr() { :; }
EOS
  run_bebash list --json
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.[] | select(.name == "gpr" and .origin == "data" and (.desc | contains("quote")))' >/dev/null
}
