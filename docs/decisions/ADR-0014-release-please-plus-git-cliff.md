# ADR-0014: release-please + git-cliff

## Context and Problem Statement

We want, for a Bash repo, what release-plz gives Rust: automated version bump,
changelog, and a review gate before publish, driven by Conventional Commits
(see [ADR-0013](ADR-0013-conventional-commits-and-semver.md)). Bash has no
package registry, so "publish" means tag + GitHub Release. We need a tool that is
language-agnostic and preserves a human merge gate.

## Considered Options

- `semantic-release` — push-model, no release-PR gate, Node plugin sprawl.
- `cocogitto` — good, but its binary is literally `cog`, clashing with the
  sibling `cog` project.
- `release-please` (release-PR gate, `simple` type) + `git-cliff` (changelog
  templating).

## Decision Outcome

Chosen option: **release-please + git-cliff**. release-please maintains a Release
PR (version bump in its manifest + changelog); merging it is the human gate and
creates the tag + GitHub Release. git-cliff owns the changelog format.

## Consequences

- Good: satisfies the release-PR invariant; GitHub-native, zero infra; stops at
  tag/Release (correct for a registry-less Bash project); avoids the `cog` name
  clash.
- Good: `git-cliff` gives full control of changelog grouping/links via
  `cliff.toml`.
- Bad: two tools instead of one.
- Bad (superseded): release-please's `simple` strategy tracks the version in a
  manifest file. See
  [ADR-0018](ADR-0018-committed-version-is-authoring-sot.md): the committed
  `VERSION` is the authoring source of truth, bumped by git-cliff — no manifest,
  nothing to keep in sync.

## Status

Superseded by [ADR-0017](ADR-0017-git-cliff-owns-version-bump.md). release-please
was removed: its `simple` type cannot bump a marker-less `VERSION` (its generic
updater no-ops without an `x-release-please-version` marker), it is GitHub/Node-
coupled, and it commits a second version copy that must stay in sync — the drift
surface. git-cliff `--bump` writes the committed `VERSION` deterministically. The
reasoning is retained here so the choice is not reopened.
