# ADR-0027: Verification and Doctor SoT

## Context

bebash needs one discoverable way for humans, scripts, and agents to validate a
payload and user overlay. The existing `doctor` command only checks environment
basics, while convention checks live in docs and repository lint.

## Decision

bebash ships a structural verifier engine in `lib/verify.bash`. `bebash doctor`
is the single public source of truth for checks: it runs environment checks,
structural verifier checks, and presence-gated `shellcheck`/`shfmt`
orchestration over user artifacts. No separate public `check` or `verify`
command ships now.

Tool orchestration reuses the repository `.shellcheckrc` and
`shfmt -i 2 -ci -bn -s`; bebash does not introduce divergent config.

## Options

- Separate `verify` command.
- Doctor runs all checks. Chosen.
- Structural-only checks.

## Consequences

Agents and humans have one entry point. `doctor --json` becomes a richer object,
which is acceptable before v1. Repository payload lint remains owned by
`just lint`; installed doctor syntax-checks payload files and runs external tools
only over user artifacts.

## Status

Accepted
