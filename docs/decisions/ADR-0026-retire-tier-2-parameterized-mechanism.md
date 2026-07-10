# ADR-0026: Retire the Tier-2 parameterized mechanism

## Context and Problem Statement

[ADR-0011](ADR-0011-privacy-strip-three-tiers.md) split source functions into three
tiers and [ADR-0012](ADR-0012-parameterize-project-shortcuts.md) added Tier 2:
"generic behavior that hardcodes the author's layout — ship the mechanism, drive
targets from config" (`p` reading `BEBASH_PROJECT_ROOTS`; the `__project_nvim`
helper behind `docs`/`notes`/`todo`/`dot`). In practice a mechanism that only does
anything useful once the user supplies personal targets is still **personal** — it
carries a user-nicety dependency the generic base should not own. Tier 2 blurs the
public/personal boundary and is the only reason the base ships a function nobody can
use unconfigured.

## Considered Options

- Keep Tier 2 as-is.
- Keep the mechanism but drop only `p`.
- Retire Tier 2 entirely: the base ships Tier 1 (generic) only; every personal
  function *and its mechanism* lives in the user overlay (Tier 3).

## Decision Outcome

Chosen option: **retire Tier 2**. The framework ships only Tier-1 generic tooling;
anything that needs a personal target — `functions/p.bash`, `lib/project.bash`
(`__project_nvim`), and the `BEBASH_PROJECT_ROOTS` config surface — moves to the
user's overlay, deployed the same way as any other personal (Tier-3) code. The tier
model becomes binary: generic ships, personal overlays.

## Consequences

- Good: a clean public/personal boundary — no shipped function is inert without
  user config; the base is smaller and unambiguously generic.
- Good: the overlay mechanism already carries `notes`/`todo`/`dot`, so it absorbs
  `p`/`project.bash` with no new machinery.
- Bad: users who relied on the shipped `p`/`__project_nvim` must copy them into
  their overlay (a one-time migration); this is a breaking change to the base.

## Status

Accepted — supersedes [ADR-0011](ADR-0011-privacy-strip-three-tiers.md) (the Tier-2
row) and [ADR-0012](ADR-0012-parameterize-project-shortcuts.md). Enacted by removing
`functions/p.bash`, `lib/project.bash`, and `test/fn_p.bats`, and by dropping the
Tier-2 surface from [reference/privacy-tiers.md](../reference/privacy-tiers.md) and
[reference/config-and-xdg.md](../reference/config-and-xdg.md).
