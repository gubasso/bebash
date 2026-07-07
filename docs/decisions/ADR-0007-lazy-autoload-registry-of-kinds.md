# ADR-0007: Lazy autoload registry of kinds

## Context and Problem Statement

Today only functions are lazy-loaded (registered as stubs, sourced on first
call). Helpers and libs are either eager or hand-guarded. As the shipped surface
grows, eager-sourcing everything would slow interactive startup. We want one
mechanism that defers functions, libs, and future module groups alike, keeping
startup O(1).

## Considered Options

- Keep functions lazy; leave libs eager or ad-hoc guarded.
- Use `command_not_found_handle` to source anything on demand.
- Generalize the autoloader into a **registry keyed by kind**
  (`function` / `lib` / `module`) with an explicit `__bebash_require_lib`.

## Decision Outcome

Chosen option: **registry of kinds**. `function` files register as callable
stubs; `lib`/`module` files register as records that a command pulls in with
`__bebash_require_lib <name>` (guarded, sourced once).

## Consequences

- Good: uniform deferral; commands declare deps cheaply
  (`__bebash_require_lib git`); startup cost is a cheap index, not N sources.
- Good: avoids `command_not_found_handle`, which fires on every missing command
  and muddies error reporting.
- Bad: a first call pays a one-time source cost; the registry is one more piece
  of core machinery to maintain. The output primitives are deliberately excluded
  (see [ADR-0010](ADR-0010-eager-load-output-libs-before-helpers.md)).

## Status

Accepted — enacted by `lib/autoload.bash` + the `rc.d` registration step; API in
[reference/module-and-loader.md](../reference/module-and-loader.md).
