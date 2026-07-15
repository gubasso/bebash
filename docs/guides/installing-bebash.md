# Guide: Installing bebash

Get bebash onto a machine and wired into your shell. For the exact paths the
installer writes and its manifest mechanics, see
[../reference/installer-and-manifest.md](../reference/installer-and-manifest.md).

## Prerequisites

- `bash` 4.4+ (the framework uses `inherit_errexit`, associative arrays).
- `git`, `just`.
- `$PREFIX/bin` on your `PATH` (default `~/.local/bin`) so the `bebash` CLI
  resolves. Optional tools (`fzf`, `scdoc`, `git-cliff`) enable extra features
  and are guarded — absence degrades gracefully.

## Install

```bash
git clone https://github.com/gubasso/bebash
cd bebash
just install
```

`just install` delegates to `install.sh`, which:

1. copies the payload to `$PREFIX/lib/bebash/` (default `~/.local/lib/bebash/`);
2. installs the `bebash` CLI as a real executable in `$PREFIX/bin`
   (it self-locates its library root — no symlink into the payload);
3. installs completion and the man page to their XDG locations;
4. records every written path in a manifest under `$XDG_STATE_HOME/bebash/`;
5. links overlay commands into `$PREFIX/bin` via `bebash link-commands` (if any).

It does **not** touch your `~/.bashrc` — shell wiring is a manual step (next
section). Override the location with `PREFIX=/usr/local just install` (or run as
root for a system install).

## Shell wiring (manual)

The installer never edits your shell rc: `~/.bashrc` is user-authored
configuration, and mutating it at runtime violates one-writer-per-file and breaks
on a read-only / Home-Manager-managed rc
([ADR-0033](../decisions/ADR-0033-installer-never-mutates-user-shell-config.md),
superseding the auto-wiring of
[ADR-0006](../decisions/ADR-0006-idempotent-bashrc-marker-block.md)/[ADR-0019](../decisions/ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md)).

Add this line yourself — or let your config manager (Home Manager, stow, chezmoi)
own it. Put it near the **top** of your interactive shell rc, **before** your
personal config, so your own settings can override bebash defaults:

```bash
[[ $- == *i* ]] && [[ -r "$HOME/.local/lib/bebash/init.bash" ]] &&
  source "$HOME/.local/lib/bebash/init.bash"
```

Use the resolved payload `init.bash` path the installer prints (default
`$HOME/.local/lib/bebash/init.bash`). The `[[ $- == *i* ]]` guard keeps
non-interactive shells from paying for it; the `-r` guard makes the line inert if
bebash is ever removed.

> **Nix / Home Manager users:** wire the source line declaratively (e.g.
> `programs.bash.initExtra` or a `~/.bashrc` rendered by your config), positioned
> early. Do not rely on the installer — it deliberately writes nothing here.

## Activate

Open a new interactive shell (or re-source your rc). Then:

```bash
bebash doctor      # health check: paths, versions, overlay status
bebash list        # list available functions with their descriptions
git-branch-gone -h # any shipped function is now available
```

## Set up your overlay (optional)

Scaffold your personal layer at `~/.config/bebash/`:

```bash
bebash init --non-interactive
```

Then add your own functions and config as described in
[creating-a-user-overlay.md](creating-a-user-overlay.md).

## Uninstall

```bash
just uninstall
```

This reads the manifest, removes only the files bebash installed, and prunes empty
dirs. It does **not** touch your `~/.bashrc` (it never wrote there) — remove the
source line yourself if you added it. Your overlay at `~/.config/bebash/` is left
untouched. Run it with the same `PREFIX`/`XDG_*` you installed with — the
uninstaller refuses to run if the manifest paths don't match, to avoid orphaning
files.

`dots` is now maintained as a standalone project for dotfiles management; bebash no longer installs it.
