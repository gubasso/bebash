# ADR-0035: Native command artifacts lane

## Context and Problem Statement

General-use native commands sometimes need default static resources, such as JSON rulesets, shipped
with the framework payload. ADR-0034 defined only `$BEBASH_DATA_DIR/artifacts/<command>/`, which works
for private overlays but leaves native commands without an installed resource lane.

## Considered Options

- Inline resources in the function.
- Require users to provide overlay-only artifacts.
- Add shipped native artifacts under `$BEBASH_LIB/artifacts/<command>/`.
- Amend ADR-0034 in place.

## Decision Outcome

Chosen option: **Add shipped native artifacts under `$BEBASH_LIB/artifacts/<command>/`** — native
commands can ship working defaults while preserving user override control.

`install.sh` copies `artifacts/` into `$PREFIX/lib/bebash/artifacts/`. A command that owns artifacts
checks `$BEBASH_DATA_DIR/artifacts/<command>/` first, then `$BEBASH_LIB/artifacts/<command>/`; if the
overlay subtree exists, it wins as a whole subtree. Native and overlay artifact files are never merged
to fill partial trees.

The lane is not on `PATH`, not autoloaded, and not schema-validated by `bebash doctor`; the owning
command still resolves and validates its own files. ADR-0034 remains the private overlay lane decision;
this ADR extends it for shipped native payloads instead of rewriting that record.

## Consequences

- Good: General-use commands can install with usable defaults.
- Good: Users can still override command data through the existing overlay artifacts lane.
- Bad: There are now two artifact roots to reason about.
- Bad: Artifact schema checks stay outside framework verification.

## Status

Accepted
