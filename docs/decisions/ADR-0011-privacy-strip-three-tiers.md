# ADR-0011: Privacy strip — three tiers

## Context and Problem Statement

The source functions mix genuinely reusable tooling with personal and
company-specific code (an employer's AWS profile, a personal Google Drive mount,
browser-profile logins, hardcoded personal directories). A public project must
ship only sane, generic tooling and keep anything personal out of the base.

## Considered Options

- Ship everything; tell users to delete what they don't want.
- Ship only an obviously-generic minimum; drop anything borderline.
- Classify every function into three tiers by evidence and route accordingly.

## Decision Outcome

Chosen option: **three tiers**. Tier 1 ships as-is (generic git/util tooling).
Tier 2 ships but is parameterized (generic behavior that hardcodes the author's
paths — e.g. `p`, the `__project_nvim` family). Tier 3 never ships
(`suse-*`, `*-session-login`, personal project dirs, host overlays) and moves to
the author's own `~/.dotfiles/bebash/` overlay.

The generic updater framework ships as `lib/updater.bash`; concrete OS updater
commands `pup` and `zup` are Tier 3 overlay commands.

## Consequences

- Good: the public base is clean and reusable; nothing personal leaks; the
  author keeps their extras via the same overlay mechanism everyone uses.
- Good: forces useful generalization (config-driven paths) instead of deletion
  (see [ADR-0012](ADR-0012-parameterize-project-shortcuts.md)).
- Bad: each function needs a classification call, re-verified against its source
  before shipping; the full table lives in
  [reference/privacy-tiers.md](../reference/privacy-tiers.md).

## Status

Accepted — enacted by which files land in `lib/functions/` vs the author's
overlay.
