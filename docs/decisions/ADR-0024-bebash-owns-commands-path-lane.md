# ADR-0024: bebash owns the commands PATH lane

## Context and Problem Statement

ADR-0022 and ADR-0023 left standalone command exposure to explicit symlinks in
`~/.local/bin` and said bebash does not prepend `$BEBASH_DATA_DIR/commands` to
`PATH`. In practice that dumps bebash-aware commands into the user's plain
bindir as (stow) symlinks, mixing them with unrelated user scripts and giving
them no reliable way to reach bebash's libraries and environment.

## Considered Options

- Keep per-command `~/.local/bin` symlinks (status quo).
- Have bebash prepend a managed `commands/` dir to `PATH` at interactive init,
  with a headless loader for command bootstrap.
- Invoke commands only through `bebash run <cmd>` (no PATH entry).

## Decision Outcome

Chosen option: **bebash prepends a managed commands dir to `PATH`**. A shipped
`rc.d/15-commands-path.bash` prepends `$BEBASH_DATA_DIR/commands` via
`__path_prepend` at interactive shell init (no-op when absent, deduped). A
bebash-aware command bootstraps by sourcing `$BEBASH_LIB/init-headless.bash` — a
non-interactive loader that exports the env, sources the eager output libs, and
autoloads functions/libs, but deliberately does not source `rc.d/*`. This keeps
the command lane bebash-owned and separate from the user's plain `~/.local/bin`,
and gives commands first-class access to the framework.

## Consequences

- Good: command exposure is automatic and auditable; commands reach bebash
  features through one documented bootstrap line; no per-command symlink churn.
- Bad: PATH is managed by bebash (one more implicit side effect at shell init);
  commands that rely on the loader require a bebash environment.

## Status

Accepted — supersedes the PATH-exposure clause of
[ADR-0022](ADR-0022-overlay-config-vs-data-split.md) ("user commands are exposed
by explicit symlinks in `~/.local/bin`; bebash does not prepend
`$BEBASH_DATA_DIR/commands` to `PATH`") and the exposure clause of
[ADR-0023](ADR-0023-standalone-command-lane-and-naming.md) ("command exposure
needs explicit symlink/install discipline outside the sourced framework
loader"). Implemented by `rc.d/15-commands-path.bash`, `init-headless.bash`, and
`install.sh`.
