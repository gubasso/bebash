setup() {
  bats_require_minimum_version 1.5.0
  load 'cmd_helper'
  cmd_setup
  export BEBASH_CONFIG_DIR="$XDG_CONFIG_HOME/bebash"
  export BEBASH_DATA_DIR="$XDG_DATA_HOME/bebash"
  mkdir -p -- "$BEBASH_CONFIG_DIR" "$BEBASH_DATA_DIR"
  chmod 0755 "$BEBASH_LIB/bin/bebash-cmd"
}

link_commands_harness() {
  bash -c '
    set -euo pipefail
    source "$BEBASH_LIB/lib/log.bash"
    source "$BEBASH_LIB/lib/ui.bash"
    source "$BEBASH_LIB/lib/helpers.bash"
    source "$BEBASH_LIB/lib/core.bash"
    source "$BEBASH_LIB/libexec/commands/cmd_link_commands.bash"
    export __BEBASH_BIN_DIR="$1"
    shift
    bebash::cmd::link_commands "$@"
  ' bash "$@"
}

@test "bebash-cmd reports unknown command with exit 127" {
  mkdir -p "$TMPDIR/bin" "$BEBASH_DATA_DIR/commands"
  ln -s "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/bin/missing"

  run -127 "$TMPDIR/bin/missing"

  [ "$status" -eq 127 ]
  [[ "$output" == *"unknown command: missing"* ]]
}

@test "bebash-cmd reports unresolved library root" {
  mkdir -p "$TMPDIR/isolated/bin"
  cp "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/isolated/bin/bebash-cmd"
  chmod 0755 "$TMPDIR/isolated/bin/bebash-cmd"

  run env -u BEBASH_LIB "$TMPDIR/isolated/bin/bebash-cmd"

  [ "$status" -eq 70 ]
  [[ "$output" == *"cannot locate library root"* ]]
}

@test "link-commands creates an idempotent shim and records manifest" {
  mkdir -p "$TMPDIR/bin" "$BEBASH_DATA_DIR/commands"
  cp "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/bin/bebash-cmd"
  chmod 0755 "$TMPDIR/bin/bebash-cmd"
  printf '#!/usr/bin/env bash\nprintf hello\\n\n' >"$BEBASH_DATA_DIR/commands/hello"
  chmod 0755 "$BEBASH_DATA_DIR/commands/hello"

  run link_commands_harness "$TMPDIR/bin" --json

  [ "$status" -eq 0 ]
  [ -L "$TMPDIR/bin/hello" ]
  [ "$(readlink "$TMPDIR/bin/hello")" = "$TMPDIR/bin/bebash-cmd" ]
  grep -Fx "$TMPDIR/bin/hello" "$XDG_STATE_HOME/bebash/commands-manifest"
  printf '%s\n' "$output" | jq -e '.linked == 1 and .skipped == 0 and .pruned == 0' >/dev/null

  run link_commands_harness "$TMPDIR/bin" --json

  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.linked == 1 and .skipped == 0 and .pruned == 0' >/dev/null
}

@test "link-commands skips reserved command names" {
  mkdir -p "$TMPDIR/bin" "$BEBASH_DATA_DIR/commands"
  cp "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/bin/bebash-cmd"
  chmod 0755 "$TMPDIR/bin/bebash-cmd"
  printf '#!/usr/bin/env bash\n:\n' >"$BEBASH_DATA_DIR/commands/bebash"
  printf '#!/usr/bin/env bash\n:\n' >"$BEBASH_DATA_DIR/commands/bebash-cmd"
  chmod 0755 "$BEBASH_DATA_DIR/commands/bebash" "$BEBASH_DATA_DIR/commands/bebash-cmd"

  run link_commands_harness "$TMPDIR/bin" --json

  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | jq -e '.linked == 0 and .skipped == 2' >/dev/null
}

@test "link-commands does not clobber foreign symlinks" {
  mkdir -p "$TMPDIR/bin" "$BEBASH_DATA_DIR/commands"
  cp "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/bin/bebash-cmd"
  chmod 0755 "$TMPDIR/bin/bebash-cmd"
  printf '#!/usr/bin/env bash\n:\n' >"$BEBASH_DATA_DIR/commands/owned"
  chmod 0755 "$BEBASH_DATA_DIR/commands/owned"
  ln -s /usr/bin/true "$TMPDIR/bin/owned"

  run link_commands_harness "$TMPDIR/bin" --json

  [ "$status" -eq 0 ]
  [ "$(readlink "$TMPDIR/bin/owned")" = "/usr/bin/true" ]
  printf '%s\n' "$output" | jq -e '.linked == 0 and .skipped == 1' >/dev/null
}

@test "link-commands prunes stale managed shims" {
  mkdir -p "$TMPDIR/bin" "$BEBASH_DATA_DIR/commands" "$XDG_STATE_HOME/bebash"
  cp "$BEBASH_LIB/bin/bebash-cmd" "$TMPDIR/bin/bebash-cmd"
  chmod 0755 "$TMPDIR/bin/bebash-cmd"
  ln -s "$TMPDIR/bin/bebash-cmd" "$TMPDIR/bin/old"
  printf '%s\n' "$TMPDIR/bin/old" >"$XDG_STATE_HOME/bebash/commands-manifest"

  run link_commands_harness "$TMPDIR/bin" --json

  [ "$status" -eq 0 ]
  [ ! -e "$TMPDIR/bin/old" ]
  printf '%s\n' "$output" | jq -e '.pruned == 1' >/dev/null
}
