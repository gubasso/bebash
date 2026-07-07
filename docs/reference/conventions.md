# Reference: Conventions

The contract a piece of bebash code follows. Sits on top of
[module-and-loader.md](module-and-loader.md) (file shape, loader) and
[output-channels.md](output-channels.md) (streams).

## Naming

| Prefix           | Meaning                                          |
| ---------------- | ------------------------------------------------ |
| `__ui_*`         | Human-facing output (colored, stderr/UI).        |
| `__log_*`        | Machine-facing structured logs. Reserved.        |
| `__bebash_*`     | Internal framework machinery (registry, require).|
| `bebash::cmd::*` | CLI subcommand handlers.                          |
| `__*`            | Other private helpers, same-file, not exported.  |
| plain name       | A user-facing library function.                  |
| `BEBASH_*`       | Environment variables.                           |

## File extensions

- **Sourced** into the shell/CLI runtime → `.bash` (no shebang;
  `# shellcheck shell=bash`). This covers everything under `lib/`, including the
  CLI machinery `core.bash`, `loader.bash`, and `commands/cmd_*.bash`.
- **Executed** top-level scripts → `.sh` (`install.sh`, `uninstall.sh`, and their
  sourced helper `install-common.sh`, which stays in that family).
- The CLI entry point `bin/bebash` has no extension (it is the command name).

## File header

- Sourced files: line 1 `# shellcheck shell=bash`; line 2 `: 'desc: …'`.
- Executables (`bin/bebash`, `install*.sh`, `uninstall.sh`): `#!/usr/bin/env bash`
  + strict mode.
- One public function per file; filename == the public name.
- A lazily-sourced lib guards itself with `__bebash_<libname>_loaded` (mandatory
  guard-variable name) so repeat sourcing is a cheap no-op
  ([module-and-loader.md](module-and-loader.md#load-guards)).

## Standard flags

| Flag         | Behavior                                                          |
| ------------ | ----------------------------------------------------------------- |
| `-h, --help` | Print usage (from a reusable `__<name>_usage`), exit `0`.         |
| `-y, --yes`  | Skip confirmation; pass straight to `__ui_confirm`.               |
| unknown `-*` | `__ui_err` + exit `2`. Never half-apply.                          |

## Dependencies

Guard user-facing commands with `__require_verbose <cmd>…` (reports each missing
tool via `__ui_err`, returns `1` if any is absent, `0` if all present). Use bare
`__require` only for silent `rc.d/` startup guards. Pull shared libs with
`__bebash_require_lib <name>` inside the function, not at file top, so startup
stays lazy (returns `69`/EX_UNAVAILABLE if the lib is unregistered —
[module-and-loader.md](module-and-loader.md#__bebash_require_lib-name)).

## Exit codes

`0` ok, `1` operational failure, `2` usage error; richer CLI failures use sysexits
([exit-codes.md](exit-codes.md)). Reserve `2` for "called me wrong".

## Pre-ship checklist

- [ ] Human messages use `__ui_*`; machine/debug events use `__log_*`.
- [ ] Result data goes to stdout, plain and parseable.
- [ ] No hardcoded ANSI; colors come from `__UI_SGR` / `__ui_*` helpers.
- [ ] Output is plain when piped and honors `NO_COLOR`; any child-shell renderer
      (e.g. fzf preview) sources `ui.bash` and sets `FORCE_COLOR=1`.
- [ ] `-h/--help` prints usage from a reusable `__<name>_usage`, exits `0`.
- [ ] Confirmation uses `__ui_confirm`; all three return codes handled; `-y/--yes`
      supported; non-TTY without `--yes` fails loudly.
- [ ] Dependencies guarded with `__require_verbose`; libs pulled via
      `__bebash_require_lib`.
- [ ] Exit codes: `0` ok, `1` failure, `2` usage (extras documented in a header).
- [ ] `command <tool>` used for external calls inside the function.
- [ ] File starts with `# shellcheck shell=bash`; `: 'desc: …'` marker present.
- [ ] No personal paths/credentials — Tier-checked
      ([privacy-tiers.md](privacy-tiers.md)).
- [ ] A `test/fn_<name>.bats` (or `cmd_*`) exists; `just lint` and `just test` pass.
