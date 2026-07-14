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

The installer copies the payload to `$PREFIX/lib/bebash/`, symlinks the CLI into
`$PREFIX/bin`, installs completion and the man page under XDG data paths, records
a manifest, and leaves your overlay intact. It also adds one guarded line to
your `~/.bashrc` (inside an idempotent marker block, never a blind append):

```bash
# >>> bebash >>>
[[ $- == *i* ]] && [[ -r "/home/me/.local/lib/bebash/init.bash" ]] &&
  source "/home/me/.local/lib/bebash/init.bash"
# <<< bebash <<<
```

The installer writes the actual resolved payload path for your machine, not the
sample `/home/me/...` path. Open a new shell and your functions are available.

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
