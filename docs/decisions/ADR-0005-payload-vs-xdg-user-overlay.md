# ADR-0005: Payload vs XDG user overlay

## Context and Problem Statement

bebash ships an immutable base but must let users add and override functions,
libs, `rc.d` modules, and config **without editing shipped files** (which a
re-install would clobber) and without forking. We need two clearly separated
layers with defined precedence.

## Considered Options

- One directory the user edits directly (oh-my-bash-classic style).
- Copy defaults into the user dir on install, then let them edit copies.
- Two layers: an installer-owned payload and a never-touched XDG user overlay,
  with the overlay layered on top at load time.

## Decision Outcome

Chosen option: **payload + overlay**. Payload lives at `$PREFIX/lib/bebash/`
(clobbered on re-install). The user overlay lives at `~/.config/bebash/` (never
touched by the installer) and is layered on top by `init.bash`.

## Consequences

- Good: upgrades never destroy user content; the base stays pristine and
  greppable; user files **win** by loading last
  (see [reference/overlay-precedence.md](../reference/overlay-precedence.md)).
- Good: the overlay can itself be a dotfiles-managed package, so personal
  config and code can stay in a private source tree while bebash reads only the
  deployed XDG config/data roots.
- Bad: two locations to reason about; the load order must be exactly right for
  overrides to take effect.

## Status

Superseded by
[ADR-0022](ADR-0022-overlay-config-vs-data-split.md). Keep for decision history.
