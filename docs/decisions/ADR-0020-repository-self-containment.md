# ADR-0020: The repository is self-contained

## Context and Problem Statement

Projects rot when load-bearing knowledge lives only outside the repo — in an external doc that
moves or link-rots, or on a maintainer's personal machine, private path, or mutating tool. A
contributor or agent then cannot understand, build, or operate the project from the checkout alone.
The docs shelf already asserts this ("this shelf is self-contained; provenance to public upstreams
only"), but the rule was never recorded as a decision.

## Considered Options

- Reference external docs freely as the source of truth.
- Keep all load-bearing knowledge in-repo; treat external links as optional further reading.
- Mix both with no rule.

## Decision Outcome

Chosen option: **keep all load-bearing knowledge in-repo** — the checkout is complete on its own. An
external reference is allowed only as a public link or citation for further reading, never as a
load-bearing dependency on a resource outside the repository, and in particular never on an
external, local, personalized, or mutating repository, path, or tool. When external knowledge is
load-bearing, its essential substance is copied in-repo (a doc, an ADR, or an inline note) so the
`docs/` shelf, the runtime, the CLI, the installer, and the tests all resolve from the repo alone.
The `docs/AGENTS.md` digest's provenance stays public-upstreams-only, matching this rule.

## Consequences

- Good: the repo is self-explanatory and resilient to link rot; contributors and agents work from
  one source; the framework a user clones carries everything it needs.
- Bad: some duplication of external material, and a discipline cost to keep copied knowledge current.

## Status

Accepted — enacted by the [root `AGENTS.md`](../../AGENTS.md) working conventions and the
public-upstreams-only provenance of the [`docs/AGENTS.md`](../AGENTS.md) digest.
