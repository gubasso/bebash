# ADR-0004: Install with `just` + `install.sh`

## Context and Problem Statement

Users install by cloning and running one command. We need an install mechanism
that is idempotent, XDG-aware, `PREFIX`-overridable, non-destructive to user
content, and uninstallable. We also want consistency with the sibling `cog`
project's toolchain so maintenance habits transfer.

## Considered Options

- GNU Make with the install-standards `PREFIX`/`DESTDIR` targets.
- A hand-rolled `curl | bash` bootstrap.
- `just install` delegating to a `install.sh` shell script (cog's pattern).

## Decision Outcome

Chosen option: **`just install` → `install.sh`** — the `justfile` is the task
surface (`install`, `uninstall`, `lint`, `test`, `dist`, `man`); `install.sh`
owns the real mechanics (copy payload, symlink, write manifest).

## Consequences

- Good: matches `cog`, so recipes and muscle memory transfer; `just` gives a
  discoverable task list; the heavy logic stays in a testable shell script.
- Good: manifest-based uninstall and idempotent re-install
  (see [reference/installer-and-manifest.md](../reference/installer-and-manifest.md)).
- Bad: adds `just` as a build-time dependency; diverges from the pure-Make
  convention some Bash projects follow. A `dist` recipe (git archive + sha256sum)
  covers release tarballs regardless.

## Status

Accepted — enacted by `justfile`, `install.sh`, `install-common.sh`,
`uninstall.sh`.
