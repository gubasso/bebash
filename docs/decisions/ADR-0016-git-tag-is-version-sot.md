# ADR-0016: The git tag is the version source of truth

## Context and Problem Statement

[ADR-0014](ADR-0014-release-please-plus-git-cliff.md) left the version number in
two committed places — a repo-root `VERSION` file and release-please's
`.release-please-manifest.json` — that "stay in sync." Keeping two
hand-reconciled copies is a drift hazard, and release-please's `simple`
type cannot even update a bare `VERSION` file: its `extra-files` generic
updater needs an
`x-release-please-version` marker, so a marker-less `VERSION` is silently skipped
and goes stale against the tag. We need exactly one source of truth that CI cannot
desync.

## Considered Options

- Annotate `VERSION` with an `x-release-please-version` marker so release-please
  bumps it — pollutes a file meant to be a bare `X.Y.Z` that `bebash version` reads.
- Rename `VERSION` → `version.txt` (what `simple` updates natively) — churns every
  doc/ADR that names `VERSION`, and still commits a second version store.
- Make the **git tag** the sole source of truth; `VERSION` becomes a generated
  artifact; drop it from `extra-files`.

## Decision Outcome

Chosen option: **the git tag is the sole source of truth** — the version is
expressed once (the tag) and everything else derives from it, so there is nothing
to keep in sync. The release-please manifest is the bot's own coordination state
(committed because the tool requires it, never hand-edited), not a competing
source. `VERSION` is not committed (`/VERSION` is git-ignored); `just dist` and
`install.sh` generate it from `git describe --tags` (leading `v` stripped), and
`bebash version` falls back to `git describe` when it is absent.

## Consequences

- Good: no committed version duplication; release-please never touches `VERSION`,
  so CI cannot leave it stale; leverages the pre-existing `git describe` fallback.
- Bad: `just dist`/`install.sh` must derive and bake `VERSION`; a dev checkout
  reports a `git describe` descriptor rather than a clean `X.Y.Z`.

## Status

Superseded by [ADR-0018](ADR-0018-committed-version-is-authoring-sot.md). The
"git tag is the sole source of truth / VERSION is generated" model was reversed:
the committed `VERSION` file is the *authoring* source of truth and the signed
`v*` tag is the *published record*, cut to mirror it. `VERSION` is committed
again (no `/VERSION` gitignore, no build-time generation); `git-cliff --bump`
writes it. The reasoning is retained so it is not reopened.
