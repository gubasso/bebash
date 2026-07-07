# ADR-0008: Reserve the `__log_*` namespace for machines

## Context and Problem Statement

A single set of message helpers was serving both humans (colored status at the
terminal) and machines (agents/scripts tailing a log). One surface for two
audiences means every consumer must strip or add formatting, and stdout stops
being a clean data pipe. We need an unambiguous boundary.

## Considered Options

- One namespace, add flags to toggle color/format per call.
- Route everything through stdout and let callers filter.
- Split by audience: reserve `__log_*` for machine records; give humans a
  separate `__ui_*` namespace.

## Decision Outcome

Chosen option: **reserve `__log_*` for machines** — structured `key=value`, no
ANSI, written to a log file — and put all human-facing output under `__ui_*`.
The name of the function tells you the audience.

## Consequences

- Good: a coding agent tailing the log gets clean records with nothing to strip;
  a human gets colored, terse status; stdout stays a pure data pipe.
- Good: the boundary is greppable (`__log_` vs `__ui_`), so reviews catch
  misrouted output.
- Bad: contributors must learn which namespace an audience maps to; the model is
  documented in [explanation/output-model.md](../explanation/output-model.md).

## Status

Accepted — enacted by `lib/log.bash` (`__log_*`) and `lib/ui.bash` (`__ui_*`).
APIs: [reference/log-api.md](../reference/log-api.md),
[reference/ui-api.md](../reference/ui-api.md).
