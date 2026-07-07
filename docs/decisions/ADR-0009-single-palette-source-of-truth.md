# ADR-0009: Single palette source of truth

## Context and Problem Statement

ANSI color codes were redefined in several places (per-function color blocks,
`tput` calls, hand-rolled `c_*` variables). Duplicated palettes drift: the same
semantic role ("warning") ends up different shades in different tools, and color
gating gets reimplemented inconsistently.

## Considered Options

- Let each function define the colors it needs.
- A shared list of raw color constants (still no gating discipline).
- One semantic palette plus one gating function, both in `lib/ui.bash`.

## Decision Outcome

Chosen option: **single semantic palette** (`__UI_SGR`: `error`, `warn`, `info`,
`ok`, `head`, `accent`, `muted`, `reset`) resolved through one gating function
(`__ui_use_color`). No ANSI is written anywhere else.

## Consequences

- Good: a color's *meaning* is consistent everywhere; changing a shade is a
  one-line edit; gating (TTY/NO_COLOR/FORCE_COLOR) is applied uniformly
  (see [reference/ui-api.md](../reference/ui-api.md)).
- Good: renderers piped into a UI (e.g. an fzf preview) opt back in with
  `FORCE_COLOR=1` instead of hardcoding escapes.
- Bad: a function that wants a bespoke color must extend the palette rather than
  inline a code — intentional friction that preserves consistency.

## Status

Accepted — enacted by `__UI_SGR` and `__ui_use_color` in `lib/ui.bash`. Rationale
for gating precedence in [explanation/output-model.md](../explanation/output-model.md).
