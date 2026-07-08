# ADR-0022: Split user config from user data

## Context and Problem Statement

ADR-0005 put all user overlay files under `$XDG_CONFIG_HOME/bebash`. That mixed
true configuration with user-authored code and startup resources, despite the
XDG Base Directory Specification distinguishing configuration data from user
data (<https://specifications.freedesktop.org/basedir-spec/latest/>).

## Considered Options

- Keep one `$XDG_CONFIG_HOME/bebash` overlay root.
- Split user files by XDG role.
- Move all user files to `$XDG_DATA_HOME/bebash`.

## Decision Outcome

Chosen option: **split user files by XDG role**. `BEBASH_CONFIG_DIR` defaults to
`$XDG_CONFIG_HOME/bebash` and contains only `config.bash` and `disabled.d/`.
`BEBASH_DATA_DIR` defaults to `$XDG_DATA_HOME/bebash` and contains user
`functions/`, `lib/`, `rc.d/`, and standalone command sources. User commands are
exposed by explicit symlinks in `~/.local/bin`; bebash does not prepend
`$BEBASH_DATA_DIR/commands` to `PATH`.

## Consequences

- Good: XDG roles are accurate, user code remains installer-owned-data-free, and
  shell startup can load code without treating config as executable content.
- Bad: users must reason about two XDG roots instead of one.

## Status

Accepted — supersedes
[ADR-0005](ADR-0005-payload-vs-xdg-user-overlay.md) and is implemented by
`init.bash`, `bin/bebash`, `lib/core.bash`, and `libexec/commands/cmd_init-user.bash`.
