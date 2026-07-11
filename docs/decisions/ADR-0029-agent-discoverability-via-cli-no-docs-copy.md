# ADR-0029: Agent Discoverability via CLI

## Context

Agents need enough local context to work in a user overlay, but copying the full
repository docs shelf into a home directory would create drift and noise.

## Decision

`bebash init` deploys one lean static pointer file, `AGENTS.md`, into the config
root. It tells agents that the authoritative, current source of truth is the CLI:
`bebash man`, `bebash help <cmd>`, `bebash doctor`, `bebash path`, and
`bebash list`.

The pointer file carries marker `bebash-agent-doc-version: 1`. `doctor` warns
when it is missing or outdated, and `init --refresh-docs` refreshes marked files.
The repository `docs/` shelf is intentionally not copied to user home.

## Options

- Copy `docs/`.
- Generate a larger doc set.
- Pointer plus CLI. Chosen.

## Consequences

The installed footprint stays small and avoids doc drift. The CLI must carry the
agent-consumable contract, especially `bebash man`, command help, and structured
`doctor` output.

## Status

Accepted
