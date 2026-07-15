# ADR-0031: Expose overlay commands through managed shims

## Context and Problem Statement

ADR-0024 put `$BEBASH_DATA_DIR/commands` on `PATH` during interactive init.
Commands launched by rofi, WM keybinds, cron, or other non-interactive parents
do not source `init.bash`, so they never receive that PATH lane or `BEBASH_LIB`.

## Considered Options

- Keep commands interactive-only and require each consumer to write wrappers.
- Put `$BEBASH_DATA_DIR/commands` on a global login/session PATH.
- Link commands into `$PREFIX/bin` through a framework-owned multicall shim.

## Decision Outcome

Chosen option: **managed multicall shims**. `bin/bebash-cmd` self-locates like
`bin/bebash`, sources `init-headless.bash`, dispatches by `basename "$0"` to
`$BEBASH_DATA_DIR/commands/<name>`, and exits `127` when no such executable
exists. `bebash link-commands` creates `$__BEBASH_BIN_DIR/<name> -> bebash-cmd`
for executable overlay commands, records them in
`$(__bebash_state_dir)/commands-manifest`, skips `bebash`/`bebash-cmd`, and
never clobbers non-links or foreign symlinks. Installer/uninstaller code uses
the matching installer state dir.

## Consequences

- Good: non-interactive launchers resolve the same overlay commands without
  per-consumer preload hacks; the shims are idempotent, prunable, and manifest
  tracked.
- Bad: every Home Manager or install generation must refresh the shim set so
  newly added commands appear in the executable bindir.

## Status

Implemented — supersedes ADR-0024's interactive-only exposure limitation and is
enacted by `bin/bebash-cmd`, `bebash link-commands`, `install.sh`, and
`uninstall.sh`.
