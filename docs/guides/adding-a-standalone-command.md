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

The public reference embed is `dots`: `bin/dots` is the executable entry point
and `lib/dots.bash` holds the implementation. The dotfiles repository is not
hardcoded; callers pass `--dir`/`--dotfiles-dir` or set `DOTFILES` or
`BEBASH_DOTFILES_DIR`.

## Overlay exposure

User-authored standalone commands live under the overlay data root:

```text
~/.local/share/bebash/commands/<name>
```

Expose them with explicit symlinks in `~/.local/bin`. bebash does not add the
commands directory itself to `PATH`; that keeps command exposure intentional and
easy to audit.

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
