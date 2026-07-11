setup() {
  load 'cmd_helper'
  cmd_setup
  # shellcheck source=lib/core.bash
  source "$BEBASH_LIB/lib/core.bash"
  # shellcheck source=lib/log.bash
  source "$BEBASH_LIB/lib/log.bash"
  # shellcheck source=lib/verify.bash
  source "$BEBASH_LIB/lib/verify.bash"
  __BEBASH_VERIFY_RESULTS=()
  mkdir -p "$XDG_CONFIG_HOME/bebash/disabled.d" "$XDG_DATA_HOME/bebash/functions" "$XDG_DATA_HOME/bebash/lib" "$XDG_DATA_HOME/bebash/rc.d" "$XDG_DATA_HOME/bebash/commands"
  cp "$BEBASH_LIB/templates/AGENTS.md" "$XDG_CONFIG_HOME/bebash/AGENTS.md"
}

has_code() {
  local code=$1 item got
  for item in "${__BEBASH_VERIFY_RESULTS[@]}"; do
    IFS=$'\t' read -r _ got _ <<<"$item"
    [[ "$got" == "$code" ]] && return 0
  done
  return 1
}

@test "verify function catalog detects source and function codes" {
  cat >"$XDG_DATA_HOME/bebash/functions/bad.bash" <<'EOF'
# bad
: 'desc: bad'
other() { :; }
extra() { :; }
EOF
  __bebash_verify_run_structural user
  has_code SRC001
  has_code FUNC002
  has_code FUNC003
}

@test "verify lib rc disabled standalone and agent doc codes" {
  cat >"$XDG_DATA_HOME/bebash/lib/no_guard.bash" <<'EOF'
# shellcheck shell=bash
: 'desc: no guard'
public() { :; }
EOF
  cat >"$XDG_DATA_HOME/bebash/rc.d/start.bash" <<'EOF'
# shellcheck shell=bash
: 'desc: rc'
public() { :; }
EOF
  mkdir -p "$XDG_CONFIG_HOME/bebash/disabled.d/bad-dir"
  cat >"$XDG_DATA_HOME/bebash/commands/tool.bash" <<'EOF'
printf '%s\n' bad
EOF
  printf '%s\n' 'old' >"$XDG_CONFIG_HOME/bebash/AGENTS.md"

  __bebash_verify_run_structural user
  has_code LIB002
  has_code LIB003
  has_code RC001
  has_code RC002
  has_code DISABLED002
  has_code STANDALONE001
  has_code STANDALONE002
  has_code STANDALONE003
  has_code AGENTDOC002
}

@test "verify does not bash-syntax-check non-shell standalone commands" {
  cat >"$XDG_DATA_HOME/bebash/commands/py-tool" <<'EOF'
#!/usr/bin/env python3
def main() -> int:
    return 0
EOF
  chmod +x "$XDG_DATA_HOME/bebash/commands/py-tool"
  __bebash_verify_run_structural user
  ! has_code SRC004
}

@test "user tool file list excludes non-shell standalone commands" {
  cat >"$XDG_DATA_HOME/bebash/commands/py-tool" <<'EOF'
#!/usr/bin/env python3
print("hi")
EOF
  cat >"$XDG_DATA_HOME/bebash/commands/sh-tool" <<'EOF'
#!/usr/bin/env bash
echo hi
EOF
  chmod +x "$XDG_DATA_HOME/bebash/commands/py-tool" "$XDG_DATA_HOME/bebash/commands/sh-tool"
  run __bebash_verify_user_tool_files
  [[ "$output" != *py-tool* ]]
  [[ "$output" == *sh-tool* ]]
}

@test "verify tool stubs report shellcheck and shfmt codes" {
  local stub="$TMPDIR/stubbin"
  mkdir -p "$stub"
  cat >"$XDG_DATA_HOME/bebash/functions/good.bash" <<'EOF'
# shellcheck shell=bash
: 'desc: good'
good() { :; }
EOF
  cat >"$stub/shellcheck" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' shellcheck-fail
exit 1
EOF
  cat >"$stub/shfmt" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' shfmt-diff
exit 0
EOF
  chmod +x "$stub/shellcheck" "$stub/shfmt"
  PATH="$stub:$PATH" __bebash_verify_run_tools user auto
  has_code TOOL002
  has_code TOOL004
}
