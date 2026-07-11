setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "init scaffolds documented config and data dirs" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "location=xdg" ]
  [ "${lines[1]}" = "config=$XDG_CONFIG_HOME/bebash" ]
  [ "${lines[2]}" = "data=$XDG_DATA_HOME/bebash" ]
  [ "${lines[3]}" = "agent_doc=$XDG_CONFIG_HOME/bebash/AGENTS.md" ]
  [ -d "$XDG_CONFIG_HOME/bebash/disabled.d" ]
  [ -f "$XDG_CONFIG_HOME/bebash/config.bash" ]
  [ -f "$XDG_CONFIG_HOME/bebash/README.md" ]
  [ -f "$XDG_CONFIG_HOME/bebash/AGENTS.md" ]
  [ -d "$XDG_DATA_HOME/bebash/functions" ]
  [ -d "$XDG_DATA_HOME/bebash/lib" ]
  [ -d "$XDG_DATA_HOME/bebash/rc.d" ]
  [ -d "$XDG_DATA_HOME/bebash/commands" ]
}

@test "init is idempotent and preserves config" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  printf '%s\n' '# sentinel' >>"$XDG_CONFIG_HOME/bebash/config.bash"

  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  grep -qx '# sentinel' "$XDG_CONFIG_HOME/bebash/config.bash"
}

@test "init custom requires path and non-tty location signal" {
  run_bebash init --location custom --non-interactive --no-doctor
  [ "$status" -eq 2 ]

  run_bebash init --no-doctor
  [ "$status" -eq 2 ]
}

@test "init dotfiles creates tree and symlinks xdg roots" {
  local target="$TMPDIR/dotfiles"
  run_bebash init --location dotfiles --path "$target" --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  [ -L "$XDG_CONFIG_HOME/bebash" ]
  [ -L "$XDG_DATA_HOME/bebash" ]
  [ -d "$target/.config/bebash" ]
  [ -d "$target/.local/share/bebash" ]
}

@test "init refuses existing non-symlink root for dotfiles" {
  mkdir -p "$XDG_CONFIG_HOME/bebash"
  run_bebash init --location dotfiles --path "$TMPDIR/dotfiles" --non-interactive --no-doctor
  [ "$status" -eq 73 ]
}

@test "init refreshes marked docs but not unmarked docs" {
  run_bebash init --non-interactive --no-doctor
  [ "$status" -eq 0 ]
  printf '%s\n' '<!-- bebash-agent-doc-version: 1 -->' 'old' >"$XDG_CONFIG_HOME/bebash/AGENTS.md"
  run_bebash init --non-interactive --no-doctor --refresh-docs
  [ "$status" -eq 0 ]
  [[ "$(cat "$XDG_CONFIG_HOME/bebash/AGENTS.md")" != *"old"* ]]

  printf '%s\n' 'custom' >"$XDG_CONFIG_HOME/bebash/AGENTS.md"
  run_bebash init --non-interactive --no-doctor --refresh-docs
  [ "$status" -eq 0 ]
  [ "$(cat "$XDG_CONFIG_HOME/bebash/AGENTS.md")" = "custom" ]
}

@test "removed init command exits 2 and init help succeeds" {
  local old_cmd="init""-user"
  run_bebash "$old_cmd"
  [ "$status" -eq 2 ]

  run_bebash init -h
  [ "$status" -eq 0 ]
  [[ "$output" == usage:* ]]
}
