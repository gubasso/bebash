# ADR-0017: git-cliff owns the version bump + changelog (release-please rejected)

## Context and Problem Statement

For a Bash project with no package registry, "release" means a signed `v*` tag plus
a GitHub Release. [ADR-0014](ADR-0014-release-please-plus-git-cliff.md) chose
release-please + git-cliff, but release-please cannot bump a bare committed
`VERSION` (its `simple` type only auto-updates a file literally named
`version.txt`; its `extra-files` generic updater rewrites only lines
carrying an `x-release-please-version` marker, so a marker-less `VERSION`
silently no-ops). It is also GitHub-App/Node-coupled and commits a second
version copy
(`.release-please-manifest.json`) that must stay in sync. We need a tool that
deterministically bumps the *committed* version file.

## Considered Options

- release-please + git-cliff (ADR-0014, prior choice) — cannot bump a marker-less
  `VERSION`; GitHub/Node-coupled; second committed copy to reconcile.
- git-cliff alone — `--bump` writes `VERSION` + `CHANGELOG.md`; the maintainer signs
  the tag.
- cocogitto — its binary is literally `cog`, clashing with the sibling `cog`
  project (still disqualifying).

## Decision Outcome

Chosen option: **git-cliff alone**. `git-cliff --bump` computes the next
SemVer from Conventional Commits and writes the bare `VERSION` and
`CHANGELOG.md`; the maintainer commits and cuts a signed `v*` tag; the
`v*`-tag CI publishes the Release and promotes `master`. No marker
comments, no manifest, nothing to drift — it bumps the
committed source directly, satisfying the committed-SoT model
([ADR-0018](ADR-0018-committed-version-is-authoring-sot.md)).

## Consequences

- Good: one tool; runs anywhere (not GitHub-locked); deterministically bumps the
  committed `VERSION`; leaner surface than config-plus-manifest automation.
- Bad: the release gate is a manual ritual/tag rather than a merged Release PR —
  acceptable, and appropriate, for a single-maintainer Bash CLI.

## Status

Accepted — supersedes
[ADR-0014](ADR-0014-release-please-plus-git-cliff.md). Enacted by
`.github/workflows/release.yml`, `cliff.toml`, and the `just release`
recipe. Flow in
[reference/release-workflow.md](../reference/release-workflow.md).
