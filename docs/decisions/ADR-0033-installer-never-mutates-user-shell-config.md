# ADR-0033: The installer never mutates the user's shell config

## Context and Problem Statement

`install.sh` used to add a guarded marker block to `~/.bashrc`
([ADR-0006](ADR-0006-idempotent-bashrc-marker-block.md)) so an interactive shell
would `source` `init.bash`. But `~/.bashrc` is user-authored **configuration**,
and editing it at runtime violates the one-writer-per-file rule: it breaks under
any config manager that renders the file read-only. On a Home Manager host
`~/.bashrc` is a symlink into the immutable `/nix/store`; the installer's
in-place rewrite (`mktemp` next to the resolved target) fails with
`Permission denied` and aborts the whole install — the concrete bug that
prompted this.

## Considered Options

- Keep editing `~/.bashrc` (marker block), patched to skip read-only targets.
- Stop touching any user shell rc; make shell integration a documented manual
  step (or a config-manager's responsibility).
- Ship a drop-in the shell auto-sources (no standard XDG drop-in for bash rc).

## Decision Outcome

Chosen option: **the installer never writes the user's shell rc.** It owns only
its own payload under `$PREFIX` and its state manifest under `$XDG_STATE_HOME`.
Shell integration — sourcing `$PREFIX/lib/bebash/init.bash` from an interactive
rc — is a **manual, documented step**, or is owned by a config manager (Home
Manager, stow, chezmoi). The post-install message prints the exact line and says
to place it **near the top** of the rc, before personal config, so user settings
override bebash defaults. `uninstall.sh` likewise never strips the rc; it reminds
the user to remove the line.

## Consequences

- Good: works everywhere, including read-only / `/nix/store`-managed `~/.bashrc`;
  honors one-writer-per-file (config is an input, never an output).
- Good: no `.bak` files, no marker block, no delicate rc rewriting.
- Bad: first-time setup gains one manual step (mitigated by an explicit,
  copy-pasteable post-install hint and the install guide).

## Status

Accepted — supersedes [ADR-0006](ADR-0006-idempotent-bashrc-marker-block.md) and
the `.bashrc`-wiring clause of
[ADR-0019](ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md). Rationale:
the `config-state-ownership` principle (one writer per file; declarative config
is an input, not an output).
