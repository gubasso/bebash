# Reference: CLI conventions

The contract for the `bebash` management CLI (the secondary surface —
[ADR-0003](../decisions/ADR-0003-dual-nature-framework-and-cli.md)). Module rules:
[module-and-loader.md](module-and-loader.md).

## Subcommand set

- `bebash doctor` — Verification checks: environment, payload/user artifact
  structure, and user shellcheck/shfmt when present.
- `bebash list` — List available functions with their `desc:`
  descriptions.
- `bebash path` — Print resolved paths (payload, config, data, log, manifest).
- `bebash edit <fn>` — Open a function in `$EDITOR` (`--new <name>`
  scaffolds one).
- `bebash init` — Scaffold user config and data roots, including dotfiles/custom
  symlink deployment.
- `bebash man` — Print the installed reference manual as plain text.
- `bebash version` — Print the version — reads the committed/installed
  `VERSION` (the authoring source of truth), falling back to
  `git describe --tags` in a dev checkout without one.
- `bebash link-commands` — Link executable overlay commands into the bebash
  bindir through `bebash-cmd` for non-interactive launchers.
- `bebash help [cmd]` — Show usage (also `-h`/`--help`).

Start with these; add more on demand. Each is one file
`libexec/commands/cmd_<name>.bash` defining `bebash::cmd::<name>`. Hyphenated
verbs normalize `-` to `_` for the file and function name.

## Per-command behavior

### `doctor`

- stdout: human report with paths, summary counts, and categorized check rows.
  `--json` emits `{ok,paths,summary,checks,logs}`. `--logs[=N]` appends log
  records, `--no-tools` skips external tools, and `--scope all|payload|user`
  selects structural scope. `bash -n` checks payload and user files; shellcheck
  and shfmt run only over user artifacts.
- Failure → exit: `1` if any `fail` check exists; `0` if only warnings exist;
  `2` for usage errors.

### `list`

- stdout: one row per registered function: `<name>  <desc>` (from the
  `desc:` marker), sorted; shows shipped vs data origin. `--json`
  emits `[{name,desc,origin}]`.
- Failure → exit: `0` always (empty list is valid).

### `path`

- stdout: resolved paths, one `key=value` per line: `payload`, `config`,
  `data`, `log`, `manifest`, `completion`, `man`. `--json` emits an object.
- Failure → exit: `0`.

### `edit <fn>`

- stdout: nothing on stdout; opens `$EDITOR` on the file. `--new <name>`
  scaffolds from `templates/` into `$BEBASH_DATA_DIR/functions` first.
- Failure → exit: `2` if `<fn>` is missing and `--new` absent; `69` if
  `$EDITOR` unset.

### `init`

- stdout: prints `location=<mode>`, `config=<path>`, `data=<path>`, and
  `agent_doc=<path>/AGENTS.md`.
- Flags: `--location xdg|dotfiles|custom`, `--path DIR`, `--refresh-docs`,
  `--no-doctor`.
- Failure → exit: `0` when scaffold and doctor are clean; `1` when scaffold
  succeeds but doctor finds failures; `2` for usage or prompt-safety errors;
  `73` when a directory or symlink cannot be created. Existing non-symlink
  XDG roots are never replaced for dotfiles/custom modes.

### `man`

- stdout: deterministic plain-text manual. `--source` prints the scdoc source.
- Failure → exit: `66` when no manual source can be found.

### `version`

- stdout: the version string only.
- Failure → exit: `0`.

### `link-commands`

- stdout: nothing by default; `--json` emits
  `{linked,skipped,pruned,created,skipped_items,pruned_items}`.
- Behavior: scans executable files in `$BEBASH_DATA_DIR/commands`, skips
  `bebash` and `bebash-cmd`, creates atomic symlinks in `$__BEBASH_BIN_DIR` to
  `bebash-cmd`, and records managed links in
  `$(__bebash_state_dir)/commands-manifest`. Existing non-links and foreign
  symlinks are left untouched. `--dry-run` reports without changing files;
  `--prune-only` removes stale managed links without creating new ones.
- Failure → exit: `2` for usage errors; `70` when the launcher/bindir context is
  unavailable.

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
shape ([exit-codes.md](exit-codes.md)), `doctor`, `init`, completion, and
`bebash man`. No separate public `check` command ships; `doctor` owns
verification. This keeps bebash legible to scripts and coding agents, not just
humans.

## Sources

- CLI guidelines: <https://clig.dev/>
