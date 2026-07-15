# bebash

A self-contained, XDG-friendly **Bash framework** — fish-style lazy-autoloaded
functions, a small generic `rc.d` startup lane, and a split human/machine output
layer — that **also** ships a small `bebash` management CLI. Clone it, run
`just install`, and layer your own functions and config on top without forking.

> Status: implementation in progress. The [`docs/`](docs/) shelf is the
> specification that drives the runtime, CLI, installer, and tests.

## Why

- **Sharp startup.** Functions, helpers, and libs are registered as cheap stubs
  and sourced on first use — startup stays O(1) regardless of how much ships.
- **Clean output.** `__ui_*` for humans (colored, TTY-aware), `__log_*` for
  machines (structured `key=value`, never colored), plain stdout for results.
- **Yours on top of ours.** A shipped, immutable base plus an XDG user overlay
  (`~/.config/bebash/`) where your functions and config **win** over the defaults.
- **Generic startup.** The shipped `rc.d` lane exposes bebash-managed commands on
  `PATH` and enables bash-only navigation conveniences (`autocd`, `direxpand`,
  `cdable_vars`) for interactive shells.

## Install

```bash
git clone https://github.com/gubasso/bebash
cd bebash
just install
```

The installer copies the payload to `$PREFIX/lib/bebash/`, installs the CLI into
`$PREFIX/bin`, installs completion and the man page under XDG data paths, records
a manifest, and leaves your overlay intact. If your overlay has executable
commands in `$BEBASH_DATA_DIR/commands`, it also runs `bebash link-commands` so
those commands resolve from non-interactive launchers through the self-locating
`bebash-cmd` shim.

### Shell integration (manual — one writer per file)

The installer **never edits your `~/.bashrc`**: that is user-authored config, and
mutating it at runtime would break a read-only / Home-Manager-managed rc
([ADR-0033](docs/decisions/ADR-0033-installer-never-mutates-user-shell-config.md)).
Wire it yourself — or let your config manager (Home Manager, stow, chezmoi) own
it. Add this near the **top** of your interactive shell rc, **before** your
personal config, so your settings override bebash defaults:

```bash
[[ $- == *i* ]] && [[ -r "$HOME/.local/lib/bebash/init.bash" ]] &&
  source "$HOME/.local/lib/bebash/init.bash"
```

Use the resolved payload path the installer prints (default
`$HOME/.local/lib/bebash/init.bash`). Open a new interactive shell and your
functions are available. See
[docs/guides/installing-bebash.md](docs/guides/installing-bebash.md).

## Documentation

Everything lives in [`docs/`](docs/README.md), organized by
[Diátaxis](https://diataxis.fr/) reader need:

- **Understand** the design → [`docs/explanation/`](docs/explanation/architecture.md)
- **Do** a task → [`docs/guides/`](docs/guides/installing-bebash.md)
- **Look up** a spec → [`docs/reference/`](docs/reference/project-layout.md)
- **Why** a choice was made → [`docs/decisions/`](docs/README.md#decisions)

Coding agents: start at [`docs/AGENTS.md`](docs/AGENTS.md).

## License

See [LICENSE](LICENSE).
