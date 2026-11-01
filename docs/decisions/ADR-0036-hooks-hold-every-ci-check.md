# ADR-0036: The Hooks Hold Every Check of CI

## Context and Problem Statement

CI ran a bats matrix over bash 4.4, 5.0, and 5.2 that no local hook ran, so a
push that passed the hooks could fail CI. The pre-push stage
also repeated every hook of the pre-commit stage, and the `markdownlint-cli2`
hook installed only where a `node` happened to be on `PATH`. The workspace
rules of the maintainer (nix-secrets ADR-0077, ADR-0078, and ADR-0079) require
that the hooks hold every check of CI and that the devshell supplies what a
hook cannot install.

## Considered Options

- Keep the matrix in CI only, and list it as a CI-only check.
- Run the matrix in a pre-push hook, on bash builds that the flake pins.
- Run the matrix in the pre-commit stage.

## Decision Outcome

Chosen option: **a pre-push hook on bash builds that the flake pins**. Any
machine with Nix runs the matrix, so it is not a CI-only check. It is costly,
so it belongs to the pre-push stage.

- CI runs the two hook stages, with the commands of `just lint` and
  `just test`.
- `default_stages: [pre-commit]`, and `stages: [pre-commit]` on each upstream
  hook whose manifest names its own stages, keep the pre-push stage free of
  repeats.
- `flake.nix` builds each bash from its GNU tarball, with a bats whose
  shebangs point at that bash, because the nixpkgs bats pins the bash of
  nixpkgs.
- The devshell supplies `nodejs`, and `markdownlint-cli2` builds on it.

## Consequences

- Good: a push that passed the hooks passes CI, and each check runs once.
- Good: in the old CI matrix, bats itself ran on the nixpkgs bash through its
  pinned shebang. The hook runs bats on the bash under test.
- Bad: the first push on a machine builds three bash versions.
- Bad: `just test` no longer runs the `test-unit` hook on the devshell bash.
  Its matrix still runs the unit tests under bash 4.4, 5.0, and 5.2, and
  `just lint` runs `test-unit` in the pre-commit stage.

## Status

Implemented — `.pre-commit-config.yaml`, `flake.nix`, `.github/workflows/ci.yml`,
and [reference/tooling.md](../reference/tooling.md#hook-stages-and-ci).
