# ADR-0001: Extract bebash as a standalone project

## Context and Problem Statement

The functions, output layer, and lazy autoloader began life as a GNU Stow
package inside a personal dotfiles repo. They are broadly useful but assume the
Stow target path and ship personal code, so they cannot be shared as-is. We want
a project other people can install without adopting the whole dotfiles repo.

## Considered Options

- Keep it as a Stow package; document how to copy files out.
- Publish it as a `basher`/`bpkg` shell package.
- Extract a standalone, self-contained, installable project.

## Decision Outcome

Chosen option: **standalone installable project** — a cloneable repo with its own
installer, versioning, and docs, decoupled from any one machine's dotfiles.

## Consequences

- Good: shareable and versioned; a clean base others can extend via an overlay.
- Good: forces a clean split between shipped tooling and personal config
  (see [ADR-0011](ADR-0011-privacy-strip-three-tiers.md)).
- Bad: we now own an installer, release process, and public-facing API surface.

## Status

Accepted — enacted by the whole `bebash/` repo; installer per
[ADR-0004](ADR-0004-install-with-just-and-install-sh.md).
