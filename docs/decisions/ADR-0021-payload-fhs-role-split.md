# ADR-0021: Payload split by FHS role

## Context and Problem Statement

The payload used `lib/` for sourced libraries plus CLI handlers, shell
functions, `rc.d`, and templates. That hid the role of each file and made
installer, loader, and docs paths ambiguous.

## Considered Options

- Keep the old mixed `lib/` tree.
- Split payload paths by FHS/GNU role.
- Move everything to top-level directories.

## Decision Outcome

Chosen option: **split payload paths by FHS/GNU role**. `lib/` contains only
sourced shared libraries. Internal `bebash <sub>` handlers live under
`libexec/commands/`, matching the FHS `/usr/libexec` role and GNU
`libexecdir` convention (<https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch04s07.html>,
<https://www.gnu.org/prep/standards/html_node/Directory-Variables.html>).
This mirrors Git's private command exec path and `git-<command>` dispatch model
(<https://git-scm.com/docs/git#Documentation/git.txt---exec-pathltpathgt>).
Shipped interactive functions, startup files, and templates live under
top-level `functions/`, `rc.d/`, and `templates/`.

The unused lazy `module` kind is removed: no `modules/` directory exists, and
startup modules remain the `rc.d/` surface.

## Consequences

- Good: paths describe runtime role; loader and installer contracts are easier
  to audit.
- Bad: all path readers, tests, and docs need a coordinated clean break.

## Status

Accepted — supersedes path details in
[ADR-0003](ADR-0003-dual-nature-framework-and-cli.md) and is implemented by the
payload tree plus `init.bash`, `lib/core.bash`, `lib/loader.bash`, and
`install.sh`.
