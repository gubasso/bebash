# The overlay model

Why bebash has two layers, and how your files win over the shipped ones. For the
exact directory map and load order see
[../reference/overlay-precedence.md](../reference/overlay-precedence.md).

## Two layers

bebash separates what it ships from what you add:

- **Payload** — the shipped base, installer-owned. Lives at `$PREFIX/lib/bebash/`
  (default `~/.local/lib/bebash/`). Re-installing **clobbers** it: it is meant to
  be replaced wholesale on upgrade. You never edit it.
- **Overlay** — your personal layer, never touched by the installer, split by XDG
  role. Your *code* — `functions/`, `lib/`, `rc.d/`, and standalone `commands/` —
  lives at the XDG data dir `$BEBASH_DATA_DIR`
  (`${BEBASH_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bebash}`, i.e.
  `~/.local/share/bebash/`). Only true *config* — `config.bash` and a
  `disabled.d/` mask directory — lives at the XDG config dir `$BEBASH_CONFIG_DIR`
  (`${BEBASH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bebash}`, i.e.
  `~/.config/bebash/`). User executables are exposed via `~/.local/bin` symlinks.

This separation is [ADR-0022](../decisions/ADR-0022-overlay-config-vs-data-split.md)
(which supersedes [ADR-0005](../decisions/ADR-0005-payload-vs-xdg-user-overlay.md)).
The point: an upgrade can throw away and recopy the whole base without ever
risking your content, because your content isn't in the base.

## Why user files win

`init.bash` registers the shipped functions first, then registers your overlay
functions **last**. In Bash, the last definition of a function name is the one
that stays. So if you drop `~/.local/share/bebash/functions/gpr.bash`, it replaces the
shipped `gpr` stub with no configuration and no conflict — the same idea as
oh-my-bash's `custom/` directory. To *remove* a shipped function instead of
replacing it, name it in `disabled.d/` and the loader unsets it after
registration.

You extend the same way you override: a new function file, a new `rc.d/` module,
or config keys in `config.bash`. There is one mechanism for "mine on top of
theirs," and it covers add, override, and disable.

## Optional dotfiles indirection

For many users, `~/.config/bebash/` and `~/.local/share/bebash/` are just
directories they create and fill. They can also be deploy targets managed by a
dotfiles tool:

```text
dotfiles package source
      | deploy
      v
~/.config/bebash/          # config read at runtime
~/.local/share/bebash/     # code read at runtime
```

So "user overlay" means the XDG config and data roots at runtime. Nothing in
bebash knows or cares about the deploy step. This is how a user keeps Tier-3
personal functions
([ADR-0011](../decisions/ADR-0011-privacy-strip-three-tiers.md)) out of the public
base while still using them: they live in a private overlay, not the shipped
payload.

## Consequences you can rely on

- Upgrades are safe: your overlay survives every re-install.
- Overrides are free: same filename, loaded later, wins.
- The base stays pristine and greppable: no user edits hide inside it.
- One overlay mechanism serves everyone, author included.
