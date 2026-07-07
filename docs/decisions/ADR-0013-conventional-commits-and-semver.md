# ADR-0013: Conventional Commits + SemVer

## Context and Problem Statement

Automated releases need a deterministic way to decide the next version and to
generate a changelog. That requires machine-readable change intent in the commit
history and a versioning scheme that maps to it. Without a convention, version
bumps and changelogs are manual and inconsistent.

## Considered Options

- Manual version bumps + hand-written changelog.
- Changeset files committed alongside code (JS-ecosystem style).
- [Conventional Commits](https://www.conventionalcommits.org/) mapped to
  [SemVer](https://semver.org/).

## Decision Outcome

Chosen option: **Conventional Commits + SemVer**. `fix:` → patch, `feat:` →
minor, `feat!:`/`BREAKING CHANGE:` → major. Other types (`docs:`, `chore:`,
`test:`, `refactor:`) do not trigger a release. Published versions are immutable
(fix forward, never rewrite).

## Consequences

- Good: version and changelog are derived, not decided; the history is the source
  of intent; git-cliff consumes it directly (`--bump` + changelog).
- Good: contributors get a clear, checkable commit contract; changelog follows
  [Keep a Changelog](https://keepachangelog.com/).
- Bad: contributors must learn and follow the commit format; a mislabeled commit
  produces a wrong bump until corrected.

## Status

Accepted — enacted via commit-message conventions and consumed by
[ADR-0017](ADR-0017-git-cliff-owns-version-bump.md). Details in
[reference/release-workflow.md](../reference/release-workflow.md).
