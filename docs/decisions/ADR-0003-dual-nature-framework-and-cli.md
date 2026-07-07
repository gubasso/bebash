# ADR-0003: Dual nature — sourced framework + management CLI

## Context and Problem Statement

bebash is primarily a set of interactive-shell functions you `source`, but it
also needs management operations (health checks, listing functions, scaffolding
a user overlay, printing paths). Should those be more sourced functions, or a
real command? Conflating the two would bloat interactive startup and muddy the
public surface.

## Considered Options

- Framework only: expose management as more sourced functions.
- CLI only: make everything a `bebash <subcommand>` call, no sourced library.
- Dual: a sourced framework (primary) plus a thin `bebash` CLI (secondary) for
  management.

## Decision Outcome

Chosen option: **dual nature** — the framework is the primary product (sourced
via `init.bash`, lazy-autoloaded functions); the `bebash` CLI is a secondary,
explicitly-invoked tool for management only.

## Consequences

- Good: interactive startup stays lean; management logic loads only when the CLI
  runs. Clear surfaces: `lib/functions/` for the library, `lib/commands/` for the
  CLI (see [reference/module-and-loader.md](../reference/module-and-loader.md)).
- Good: the CLI can be scripted and tested independently of a login shell.
- Bad: two entry points to document and keep consistent (`init.bash` and
  `bin/bebash`); shared helpers must serve both.

## Status

Accepted — enacted by `init.bash` (framework) and `bin/bebash` +
`lib/commands/cmd_*.bash` (CLI). Subcommand set in
[reference/cli-conventions.md](../reference/cli-conventions.md).
