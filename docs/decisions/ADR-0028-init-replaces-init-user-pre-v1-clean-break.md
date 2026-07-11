# ADR-0028: Init Replaces Init-User

## Context

`bebash init-user` scaffolds the user overlay, but the command name is awkward
and does not cover dotfiles or custom deployment. bebash is still pre-v1, so
breaking CLI cleanup is allowed when it reduces permanent surface area.

## Decision

`bebash init` fully replaces `bebash init-user`. There is no alias, shim, or
back-compat command. The repository rule is: before v1, prefer clean breaks over
compatibility shims when the old behavior has not become stable API.

For dotfiles and custom deployment, `init` creates the chosen tree and wires the
runtime by symlinking the XDG config and data roots to that tree. This is
required because runtime loading reads the XDG roots. Existing non-symlink roots
are never replaced; `init` exits with a create/configuration failure instead.

## Consequences

The command registry, completions, docs, man page, and tests drop `init-user`.
A later human commit should mark the change as breaking, for example
`feat(cli)!:`. Dotfiles setup is explicit and idempotent when symlinks already
point at the intended targets.

## Status

Accepted
