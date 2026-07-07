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
2. symlinks the CLI to `$PREFIX/bin/bebash`;
3. installs completion and the man page to their XDG locations;
4. records every written path in a manifest under `$XDG_STATE_HOME/bebash/`;
5. wires your `~/.bashrc` (next section).

Override the location with `PREFIX=/usr/local just install` (or run as root for a
system install).

## Shell wiring

The installer adds a single guarded line inside an idempotent marker block —
never a blind append ([ADR-0006](../decisions/ADR-0006-idempotent-bashrc-marker-block.md)):

```bash
# >>> bebash >>>
[[ $- == *i* ]] && [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bebash/init.bash" ]] &&
  source "${XDG_CONFIG_HOME:-$HOME/.config}/bebash/init.bash"
# <<< bebash <<<
```

Re-running the installer never duplicates this block. If the block is already
present it is replaced in place; if absent, `~/.bashrc` is backed up once before
the block is appended.

## Activate

Open a new interactive shell (or `source ~/.bashrc`). Then:

```bash
bebash doctor      # health check: paths, versions, overlay status
bebash list        # list available functions with their descriptions
git-branch-gone -h # any shipped function is now available
```

## Set up your overlay (optional)

Scaffold your personal layer at `~/.config/bebash/`:

```bash
bebash init-user
```

Then add your own functions and config as described in
[creating-a-user-overlay.md](creating-a-user-overlay.md).

## Uninstall

```bash
just uninstall
```

This reads the manifest, removes only the files bebash installed, prunes empty
dirs, and strips the `.bashrc` marker block. Your overlay at `~/.config/bebash/`
is left untouched. Run it with the same `PREFIX`/`XDG_*` you installed with — the
uninstaller refuses to run if the manifest paths don't match, to avoid orphaning
files.
