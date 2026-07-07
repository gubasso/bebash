# Reference: Output channels

The channel matrix, stream discipline, and verbosity controls for bebash output.
The API details live in [ui-api.md](ui-api.md) and [log-api.md](log-api.md); the
model is [../explanation/output-model.md](../explanation/output-model.md).

## The three message types

| Type            | Audience                | Destination                     | Format            | Colored |
| --------------- | ----------------------- | ------------------------------- | ----------------- | ------- |
| human-UX        | human at a terminal     | stderr (status) / stdout (result) | prose, tables    | yes     |
| machine-output  | agents, scripts         | stdout                          | plain / `--json`  | no      |
| log-messages    | dev, agent, debugging   | `$XDG_STATE_HOME/bebash/bebash.log` | `key=value`   | never   |

## Stream discipline (non-negotiable)

- **stdout = the result only.** Data a caller pipes or redirects. A status line
  or color here breaks `cmd | jq`, `cmd > file`, and `2>/dev/null`.
- **stderr = everything else for a human.** Progress, warnings, errors, prompts.
  `__ui_*` writes here.
- **log file = machine records.** `__log_*` writes here, never to stdout.

If a value is *the answer to the command*, it is stdout and plain. If it's how the
command is going, it's stderr. If it's for a machine to reconstruct what happened,
it's the log.

## Machine output and `--json`

Human-facing commands print human output by default and switch to structured
output under `--json` (newline-delimited JSON on stdout). Machine-facing helpers
default to plain, parseable stdout. Never mix ANSI into `--json` output.

## Verbosity

Terminal log mirroring follows the standard convention (the log **file** is
always written per its own level gate — see [log-api.md](log-api.md)):

| Flag / state   | Terminal shows           |
| -------------- | ------------------------ |
| (none)         | warnings and errors      |
| `-v`           | + info                   |
| `-vv`          | + debug                  |
| `--quiet`/`-q` | errors only              |
| `--silent`     | nothing (file still logged) |

## Non-interactive behavior

| Flag                | Effect                                                        |
| ------------------- | ------------------------------------------------------------- |
| `-y` / `--yes`      | Auto-confirm yes/no prompts (`__ui_confirm` returns `0`).     |
| `--non-interactive` | Never prompt; fail loudly if a prompt would be required.      |

When stdin is not a TTY and no `--yes` was given, a command that would prompt must
fail (not hang, not silently proceed) — `__ui_confirm` returns `2` exactly so the
caller can. See [exit-codes.md](exit-codes.md).

## Color

Color gating (`NO_COLOR > FORCE_COLOR > isatty`) and the palette are specified in
[ui-api.md](ui-api.md#color-gating-__ui_use_color-fd). Only the human-UX channel
is ever colored.
