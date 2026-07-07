# ADR-0002: Name the project `bebash`

## Context and Problem Statement

The extracted project needs a name that is short, lowercase, easy to type,
searchable, and low-collision with existing shell tooling (`bash`, `sh`, `bash-it`,
`oh-my-bash`, `basher`, `bpkg`). The name is baked into the CLI binary, the XDG
directories (`~/.config/<name>`, `$PREFIX/lib/<name>`), and the function/env
prefixes, so changing it later is costly.

## Considered Options

- `bax`, `coil`, `crank` — short, punchy, low-collision, but opaque about what
  the project is.
- `gear` / `cog`-family — mechanical kinship with the sibling `cog` project, but
  `cog` as a binary already exists (cocogitto).
- `bebash` — self-describing ("be bash" / a Bash base), memorable, searchable.

## Decision Outcome

Chosen option: **`bebash`** — the user's decision; it reads as a Bash-centric
base kit, is easy to search, and doesn't collide with a well-known binary.

## Consequences

- Good: the name signals the domain (Bash) without being a generic dictionary
  word; unambiguous for the CLI, XDG dirs, and the `__bebash_*`/`BEBASH_*`
  namespaces.
- Bad: slightly longer than a 3-letter name; two adjacent "b" sounds.

## Status

Accepted — enacted as the repo name, the `bebash` CLI, `BEBASH_*` env vars, and
`~/.config/bebash/`.
