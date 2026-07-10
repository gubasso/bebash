# ADR-0012: Parameterize project shortcuts

## Context and Problem Statement

Several handy functions (`p` for fuzzy-cd; `docs`/`notes`/`todo`/`dot` opening a
fixed directory in an editor via a shared `__project_nvim` helper) are generic in
behavior but hardcode the author's directory layout (specific `~/Documents`,
`~/Notes`, `~/Sources`, `~/Projects` paths). Shipping the hardcoded targets would
be useless — or wrong — for anyone else.

## Considered Options

- Drop them all as too personal.
- Ship them with the author's paths as immovable defaults.
- Ship the **mechanism** and drive targets from user config, with sensible or
  empty defaults; personal shortcuts move to the author's overlay.

## Decision Outcome

Chosen option: **ship the mechanism, parameterize the targets**. `p` reads
`BEBASH_PROJECT_ROOTS`; the `__project_nvim` helper ships as a reusable primitive;
concrete shortcuts (`docs`, `notes`, …) are declared in the user's `config.bash`.

## Consequences

- Good: everyone gets the useful pattern; the author reproduces their exact
  shortcuts in their overlay; no personal paths in the base.
- Good: config-driven defaults are documented in one place
  (see [reference/config-and-xdg.md](../reference/config-and-xdg.md)).
- Bad: a small amount of indirection versus a hardcoded function; users must set
  config to get the personal-style shortcuts.

## Status

Superseded by [ADR-0026](ADR-0026-retire-tier-2-parameterized-mechanism.md). The
Tier-2 approach is retired: rather than shipping the mechanism and parameterizing
targets, `p` and `__project_nvim` move wholesale to the user overlay, and
`BEBASH_PROJECT_ROOTS` is no longer a framework config key.
