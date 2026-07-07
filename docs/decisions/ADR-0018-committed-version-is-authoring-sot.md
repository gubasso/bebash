# ADR-0018: Committed VERSION is the authoring source of truth; tag mirrors it

## Context and Problem Statement

A version can live in several places — a committed `VERSION` file, a
release bot's manifest, and the git tag. When more than one is
authoritative they drift.
[ADR-0016](ADR-0016-git-tag-is-version-sot.md) tried to dodge this by
making the tag the *sole* source of truth and generating `VERSION` at
build/install time, but that reversal left dev checkouts with no clean
`X.Y.Z`, coupled everything to
`git describe`, and required `just dist`/`install.sh` to derive and bake
the file. We want one authored, committed place, consistent with the
canonical
version-source-of-truth decision.

## Considered Options

- Git tag is the sole source of truth; `VERSION` generated at build/install
  (ADR-0016 — reversed).
- Keep two committed copies (`VERSION` + a bot manifest) "in sync" — the drift
  surface.
- Committed `VERSION` is the authoring source of truth; the signed `v*` tag is the
  published record, cut to mirror it.

## Decision Outcome

Chosen option: **committed `VERSION` = authoring source of truth; the
`vX.Y.Z` tag = published record, cut to mirror it**. `VERSION` (a single
line, bare `X.Y.Z`) is
committed and bumped in place by `git-cliff --bump`
([ADR-0017](ADR-0017-git-cliff-owns-version-bump.md)); the signed tag is cut to
match; a dev checkout falls back to `git describe --tags --dirty --always`
only when no `VERSION` exists. Corollary per ecosystem: Rust →
`Cargo.toml` (release-plz),
Node → `package.json` (Changesets), Bash → `VERSION` (git-cliff). A tool that cannot
bump the committed file is disqualified.

## Consequences

- Good: one authored source, no sync step, no silent drift; the tag is an immutable
  published marker distribution keys off; `just dist` is a straight `git archive`
  (`VERSION` already committed).
- Bad: the "tag is the source of truth" phrasing is retired; docs must say
  "authoring vs published."

## Status

Accepted — supersedes [ADR-0016](ADR-0016-git-tag-is-version-sot.md).
Enacted by the committed `VERSION`, `.gitignore` (no `/VERSION`),
`justfile` (`dist`), `cliff.toml`,
and `.github/workflows/release.yml`. Mirrors the canonical version-source-of-truth
decision. Flow in
[reference/release-workflow.md](../reference/release-workflow.md#version-source-of-truth).
