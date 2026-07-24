# ADR-0034: Command-private artifacts lane

## Context and Problem Statement

Standalone overlay commands sometimes need private resource files: templates,
static JSON payloads, or fixtures that are not shell code. Putting those files in
`commands/`, `functions/`, `lib/`, or `rc.d/` would either expose them as
executables or make the loader treat data as code.

## Considered Options

- Add `$BEBASH_DATA_DIR/artifacts/<command>/` for explicit command-owned data.
- Put resource files beside commands in `commands/`.
- Put resource files in `lib/` and let commands know the filenames.

## Decision Outcome

Chosen option: **Add `$BEBASH_DATA_DIR/artifacts/<command>/`** — it keeps data
inside the overlay while preserving the existing meanings of the executable and
sourced-code lanes.

Commands resolve artifacts directly, for example
`$BEBASH_DATA_DIR/artifacts/git-branch-protection/rulesets`, and own the format
and validation of their subtree.

## Consequences

- Good: Commands can ship private resources without adding files to `PATH` or
  the autoload registry.
- Good: The lane composes with the existing `$BEBASH_DATA_DIR` overlay model.
- Bad: bebash does not validate artifact schemas; each command must check its
  own files before use.

## Status

Accepted
