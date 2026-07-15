# ADR-0019: Payload init shell wiring and BEBASH_LIB root

## Context and Problem Statement

The runtime resolves `BEBASH_LIB` from the installed payload entry
`init.bash`, then discovers the XDG overlay at `config.bash`. Some install docs
instead wired `.bashrc` to an overlay `init.bash` and some loader snippets
omitted the `lib/` segment under `BEBASH_LIB`, making the delivery contract
ambiguous.

## Considered Options

- Wire `.bashrc` to the installed payload `init.bash`; `init.bash` discovers
  the overlay, and `BEBASH_LIB` means the payload root.
- Wire `.bashrc` to an overlay-owned `init.bash`.
- Make `BEBASH_LIB` mean the payload `lib/` directory.

## Decision Outcome

Chosen option: **Wire `.bashrc` to the installed payload `init.bash`;
`BEBASH_LIB` means the payload root** — this matches the shipped runtime, avoids
depending on `PREFIX`/`XDG_*` in login shells, and follows the framework
precedent in [inspiration-projects.md](../reference/inspiration-projects.md)
plus shelf entry `rs-20260708-a6425adf`.

The installer writes the install-time-resolved absolute path, for example
`/home/me/.local/lib/bebash/init.bash`, guarded by interactivity and
readability. Shipped code lives under `$BEBASH_LIB/lib/...`; the overlay remains
under `${XDG_CONFIG_HOME:-$HOME/.config}/bebash` and its entry is `config.bash`.

## Consequences

- Good: Shell startup sources one stable payload entry; user overlay files stay
  declarative and never need an `init.bash`.
- Good: CLI and shell loaders agree that `BEBASH_LIB` contains `init.bash`,
  `VERSION`, `bin/`, and `lib/`.
- Bad: Moving an installed payload to a new prefix means updating the source line
  in your rc (the source path is absolute).

## Status

Implemented: [install.sh](../../install.sh), [install-common.sh](../../install-common.sh).

The **content** of this decision stands: an interactive shell sources the
installed payload `init.bash`, and `BEBASH_LIB` means the payload root. The
**mechanism** — the installer editing `~/.bashrc` — is superseded by
[ADR-0033](ADR-0033-installer-never-mutates-user-shell-config.md): the user (or a
config manager) now adds that source line manually; the installer never writes the
rc.
