# Architecture

The mental model of what bebash *is* and how a shell session comes to have its
functions. For exact directory roles see
[../reference/project-layout.md](../reference/project-layout.md); for the loader
API see [../reference/module-and-loader.md](../reference/module-and-loader.md).

## Two natures, one repo

bebash is two things that share a code base:

1. **A sourced framework** (the primary product). You add one line to `~/.bashrc`;
   from then on your interactive shells have bebash's functions, output helpers,
   and `rc.d` startup modules. This is what people use minute to minute.
2. **A management CLI** (`bebash`, secondary). An explicitly-invoked command for
   operations that don't belong in every shell: `doctor`, `list`, `path`, `edit`,
   `init`, `man`, `version`. It loads its own code on demand and never runs as part
   of interactive startup.

Keeping these separate is a deliberate decision
([ADR-0003](../decisions/ADR-0003-dual-nature-framework-and-cli.md)): the
library surface lives in `functions/`, the CLI surface in `libexec/commands/`,
and shared machinery in `lib/` (helpers, ui, log, loader, autoload registry).

## The install picture

`just install` copies an immutable **payload** to `$PREFIX/lib/bebash/` and
installs the CLIs as real executables in `$PREFIX/bin`. Your personal additions live in a separate
**overlay**, split by XDG role — code at `~/.local/share/bebash/`
(`$BEBASH_DATA_DIR`), config at `~/.config/bebash/` (`$BEBASH_CONFIG_DIR`) — that
the installer never touches. The two
layers are explained in [overlay-model.md](overlay-model.md); the install
mechanics are in
[../reference/installer-and-manifest.md](../reference/installer-and-manifest.md).

## The load pipeline

When a new interactive shell sources `init.bash`, stages run in a fixed order:

```text
init.bash
  ├─ resolve payload dir (BEBASH_LIB), user code dir (BEBASH_DATA_DIR), user config dir (BEBASH_CONFIG_DIR)
  ├─ EAGER core:   source log.bash → ui.bash → helpers.bash → autoload registry
  ├─ register SHIPPED:  functions/ (stubs), libs (records)
  ├─ source SHIPPED rc.d/*.bash   (lexical order, generic bash-only startup)
  ├─ register USER overlay:  functions/ (win), libs
  ├─ source USER rc.d/*.bash
  ├─ source USER config.bash
  └─ apply disabled.d/  (unset masked functions)
```

Read the verbs as load semantics: **source** = run the file now (eager);
**register** = record a stub/record now and source the body only on first use
(lazy, [lazy-loading-model.md](lazy-loading-model.md)). Only the EAGER core line
and the two `source … rc.d`/`config.bash` lines actually execute file bodies at
startup; the `register` lines do not.

Two invariants make this correct:

- **The eager core comes first.** `ui`/`log`/`helpers` and the registry are
  loaded before anything else because early stages call them (a dependency guard
  must be able to print an error). This is
  [ADR-0010](../decisions/ADR-0010-eager-load-output-libs-before-helpers.md).
- **User registration comes last.** Because a stub or function defined later wins,
  a user file shadows the shipped one of the same name for free — the basis of
  the overlay's override semantics
  ([ADR-0022](../decisions/ADR-0022-overlay-config-vs-data-split.md), which
  supersedes [ADR-0005](../decisions/ADR-0005-payload-vs-xdg-user-overlay.md)).

Everything between the eager core and the overlay is *registration*, not
execution: functions and libs become cheap stubs/records and are only sourced on
first use. That is what keeps startup sharp regardless of how much ships — see
[lazy-loading-model.md](lazy-loading-model.md).

## The CLI path

`bin/bebash` is a thin shim: self-locate its library root (probing the installed
FHS layout then the repo tree), source the shared core, then dispatch to
`libexec/commands/cmd_<name>.bash`, which is sourced
only when that subcommand runs. The framework and the CLI thus share helpers but
never load each other's bulk. Conventions for the CLI surface are in
[../reference/cli-conventions.md](../reference/cli-conventions.md).
