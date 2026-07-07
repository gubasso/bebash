# ADR-0010: Eager-load output libs before helpers

## Context and Problem Statement

Most of bebash is lazy-loaded to keep startup sharp
(see [ADR-0007](ADR-0007-lazy-autoload-registry-of-kinds.md)). But the output
primitives (`__ui_*`, `__log_*`) are used *during* startup — by `rc.d/*` modules
and by dependency guards like `__require_verbose` that must report a missing tool
before anything else runs. If those primitives were lazy, early code would call
undefined functions.

## Considered Options

- Lazy-load everything uniformly, including ui/log.
- Inline a minimal fallback `echo` for early errors, lazy-load the real libs.
- Eager-load `ui.bash`, `log.bash`, and `helpers.bash` (plus the autoload
  registry) before any `rc.d/*` or function runs.

## Decision Outcome

Chosen option: **eager-load the output libs and helpers first**. `init.bash`
sources `log` → `ui` → `helpers` (and the registry) before registering functions
or sourcing `rc.d/*`.

## Consequences

- Good: every later stage can rely on `__ui_err`/`__log_*`; guards can report
  cleanly; no undefined-function races at startup.
- Good: these files are tiny and side-effect-free until called, so the eager cost
  is negligible.
- Bad: a hard ordering constraint the loader must preserve; documented as the
  fixed prefix of the load pipeline in
  [explanation/architecture.md](../explanation/architecture.md).

## Status

Accepted — enacted by the load order in `init.bash`.
