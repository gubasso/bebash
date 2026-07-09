# ADR-0025: Ship CLIs as real FHS bin files with dual-layout self-location

## Context and Problem Statement

`just install` copied the whole payload — including a `bin/` subdir — to
`$PREFIX/lib/bebash/` and then created absolute symlinks
`$PREFIX/bin/{bebash,dots}` → `$PREFIX/lib/bebash/bin/{bebash,dots}`. That is a
non-standard hop for installed executables, couples the on-PATH command to a
payload-internal path, and breaks if the payload moves.

## Considered Options

- Keep payload `bin/` + absolute symlinks on PATH.
- Copy the CLIs as real executables into `$PREFIX/bin` (standard FHS bindir);
  each self-locates its library root.
- Stamp an absolute `BEBASH_LIB` into the copied bin files at install time.

## Decision Outcome

Chosen option: **real executables in `$PREFIX/bin`** — the standard way a Bash
app installs. Libraries stay at `$PREFIX/lib/bebash`; completions/man stay under
`$PREFIX/share`; the payload no longer contains `bin/`. Each CLI resolves its
library root by probing, in order, `$bindir/../lib/bebash` (installed FHS) then
`$bindir/..` (repo working tree / old payload-bin layout), using `lib/core.bash`
as the shared sentinel. No install-time stamping: the same script works from the
repo (dev + tests) and from `$PREFIX/bin` unchanged. `BEBASH_LIB` set in the
environment still wins, so tests and power users can override.

## Consequences

- Good: installed executables live where FHS expects; no symlink hop; relocating
  the payload no longer breaks PATH; one script serves both layouts.
- Bad: the probe order is load-bearing (installed path must be tried first);
  self-location logic is slightly more code than a single `$bindir/..`.

## Status

Accepted — supersedes the "payload contains `bin/`" detail of
[ADR-0021](ADR-0021-payload-fhs-role-split.md) and refines the self-location
contract of
[ADR-0019](ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md)
(`BEBASH_LIB` still means the payload root; that root just no longer holds
`bin/`). Implemented by `bin/bebash`, `bin/dots`, `install.sh`, and
`install-common.sh`.
