# Guide: Adding a standalone command

How to add an executable command that is useful outside an interactive shell.
This is the third public lane, separate from sourced functions and `bebash`
management subcommands. Layout and loader rules are specified in
[../reference/project-layout.md](../reference/project-layout.md) and
[../reference/module-and-loader.md](../reference/module-and-loader.md).

## Pick this lane deliberately

Use a standalone command when the tool should be invoked from `PATH`, cron,
hooks, editors, or other scripts without first sourcing `init.bash`.

Do not use this lane for:

- an interactive-shell helper: put it in `functions/<name>.bash`;
- a management operation for the framework: add a `bebash <name>` subcommand in
  `libexec/commands/cmd_<name>.bash`;
- private or site-specific automation: keep it in a user overlay.

## File shape

Standalone commands live in `bin/` and are executable Bash scripts. Keep shared
logic in `lib/<name>.bash` when the command has enough behavior to test or reuse.
The executable resolves `BEBASH_LIB`, sources eager output/helper libraries, then
sources its command library.

The former in-repo reference command, `dots`, has moved to its own standalone project. New executable tools that are useful outside bebash should generally live outside this framework unless they deliberately need bebash's headless loader.

## Overlay exposure

User-authored standalone commands live under the overlay data root:

```text
~/.local/share/bebash/commands/<name>
```

bebash owns this lane: `rc.d/15-commands-path.bash` prepends
`$BEBASH_DATA_DIR/commands` to `PATH` at interactive shell init (no per-command
`~/.local/bin` symlinks). A bebash-aware command reaches the framework's
functions, libraries, and environment by sourcing the headless loader — no
`${BEBASH_LIB:-…}` fallback, since a bebash-aware command runs with `BEBASH_LIB`
exported ([ADR-0024](../decisions/ADR-0024-bebash-owns-commands-path-lane.md)):

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$BEBASH_LIB/init-headless.bash"

# …now __ui_*, __require_verbose, and autoloaded functions are available…
```

The loader sources the eager output libs and autoloads functions/libs but does
**not** run `rc.d/*` (interactive/PATH side effects stay with `init.bash`). A
command that needs none of the framework can skip the source line entirely.

Overlay standalone commands may be written in **any language** — a command with a
non-shell shebang (e.g. `#!/usr/bin/env python3`) is a first-class citizen of this
lane. `bebash doctor` honors the shebang: every standalone command is checked for
being executable, having a shebang, and not ending in `.bash`, but the
shell-only checks (bash syntax, `shellcheck`, `shfmt`) run **only** when the
shebang names a shell interpreter (`bash`/`sh` family). A Python or Perl command
is therefore verifier-clean without contortions.

## Function examples are not standalone commands

Some shipped references are sourced functions, not executables:

- `functions/ln-clean.bash` defines the interactive `ln-clean` function.
- `functions/md-create.bash` defines the interactive `md-create` function.

They follow the same output, dependency, and exit-code conventions, but they are
autoloaded by a sourced shell rather than executed from `PATH`.

## Verify

Add focused tests for the executable and any shared library. If the command is
documented for users, update `man/bebash.1.scd` or the relevant guide. Run
`just lint` and `just test`.
