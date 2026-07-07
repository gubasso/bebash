# Reference: CLI conventions

The contract for the `bebash` management CLI (the secondary surface —
[ADR-0003](../decisions/ADR-0003-dual-nature-framework-and-cli.md)). Module rules:
[module-and-loader.md](module-and-loader.md).

## Subcommand set

- `bebash doctor` — Health check: payload/overlay paths, versions,
  missing deps.
- `bebash list` — List available functions with their `desc:`
  descriptions.
- `bebash path` — Print resolved paths (payload, overlay, log, manifest).
- `bebash edit <fn>` — Open a function in `$EDITOR` (`--new <name>`
  scaffolds one).
- `bebash init-user` — Scaffold the user overlay at `~/.config/bebash/`.
- `bebash version` — Print the version — reads the committed/installed
  `VERSION` (the authoring source of truth), falling back to
  `git describe --tags` in a dev checkout without one.
- `bebash help [cmd]` — Show usage (also `-h`/`--help`).

Start with these; add more on demand. Each is one file
`lib/commands/cmd_<name>.bash` defining `bebash::cmd::<name>`.

## Per-command behavior

### `doctor`

- stdout: one line per check: `bash`≥4.4, payload & overlay dirs exist,
  CLI on `PATH`, log writable, each optional tool (`fzf`, `scdoc`,
  `git-cliff`) present/absent. `--json` emits an array of
  `{check,status,detail}`.
- Failure → exit: `1` if any required check fails; `0` if only optional
  tools are missing (they warn).

### `list`

- stdout: one row per registered function: `<name>  <desc>` (from the
  `desc:` marker), sorted; shows shipped vs overlay origin. `--json`
  emits `[{name,desc,origin}]`.
- Failure → exit: `0` always (empty list is valid).

### `path`

- stdout: resolved paths, one `key=value` per line: `payload`, `overlay`,
  `log`, `manifest`, `completion`, `man`. `--json` emits an object.
- Failure → exit: `0`.

### `edit <fn>`

- stdout: nothing on stdout; opens `$EDITOR` on the file. `--new <name>`
  scaffolds from `lib/templates/` into the overlay first.
- Failure → exit: `2` if `<fn>` is missing and `--new` absent; `69` if
  `$EDITOR` unset.

### `init-user`

- stdout: prints the overlay path it created/verified.
- Failure → exit: `0` (idempotent; never clobbers an existing overlay).

### `version`

- stdout: the version string only.
- Failure → exit: `0`.

### `help [cmd]`

- stdout: usage text (generated).
- Failure → exit: `0`; `2` if `cmd` is unknown.

Every command routes status/errors to stderr via `__ui_*` and honors the global
flags below; only the "stdout (result)" column above ever reaches stdout.

## Flag parsing

- Global flags (`--json`, `-v/-vv`, `--quiet`, `--color`, `--yes`,
  `--non-interactive`) are parsed once in `lib/core.bash` before dispatch.
- Per-command flags are parsed in the command file.
- Long and short forms both supported; `--` terminates option parsing.
- An unknown flag or command is a **usage error**: `__ui_err` + exit `2`
  (`64`/EX_USAGE at the CLI). Never half-apply a bad invocation.

## Help is generated, not authored

Usage lines, the flag table, and the subcommand list are derived from the parser
plus each file's `desc:` marker — that derivation is the single source of truth.
Hand-written prose (worked examples, environment variables, `SEE ALSO`,
cross-references) lives *around* the generated body, never duplicating the flag
table. `bebash help <cmd>` and `bebash <cmd> --help` are equivalent.

## Standard flags

- `-h`, `--help` — Print usage, exit `0`.
- `--version` — Print version, exit `0`.
- `-y`, `--yes` — Auto-confirm prompts (pass through to `__ui_confirm`).
- `--non-interactive` — Never prompt; fail loudly if input is required.
- `--json` — Structured stdout for machine consumers.
- `-v` / `-vv` / `--quiet` / `--silent` — Terminal verbosity
  ([output-channels.md](output-channels.md)).
- `--color {auto,always,never}` — Override color detection.

## Agent-facing surface

Per CLI-design guidance, the CLI exposes: `help`/usage, `--json`, a stable error
shape ([exit-codes.md](exit-codes.md)), `doctor`, `init-user`, completion, and
the man page (also readable via the CLI). This keeps bebash legible to scripts and
coding agents, not just humans.

## Sources

- CLI guidelines: <https://clig.dev/>
