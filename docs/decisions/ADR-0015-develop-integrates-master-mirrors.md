# ADR-0015: `develop` integrates, `master` mirrors releases

## Context and Problem Statement

With automated releases we need a branch model that defines where work
integrates, what triggers a release, and how the released state is represented.
Ad-hoc pushing to the default branch makes "what is released" ambiguous and lets
humans race the release automation.

## Considered Options

- Trunk-based: one branch, tag releases on it.
- GitFlow with long-lived release branches.
- Two-branch: `develop` integrates and triggers releases; `master` mirrors the
  latest published release and is written only by CI.

## Decision Outcome

Chosen option: **`develop` integrates / `master` mirrors**. Feature branches PR
into `develop`; the maintainer cuts the release on `develop` (the git-cliff
ritual: bump `VERSION` + `CHANGELOG`, commit, sign a `v*` tag). The `v*`-tag CI
**fast-forwards `master` onto that tag** (ancestry-checked, `--ff-only`); no human
pushes to `master`.

## Consequences

- Good: "what's released" is unambiguous (`master` == latest tag); the release
  path is auditable and human-race-free; branch protection enforces CI-only
  writes to `master`.
- Good: promotion is a mechanical fast-forward, not a merge commit.
- Bad: two branches to understand; contributors must target `develop`, not
  `master`. The promotion job wiring is described in
  [reference/release-workflow.md](../reference/release-workflow.md).

## Status

Accepted — enacted by branch protection + the promotion step in the release
workflow.
