# Reference: `lib/ui.bash` (human output)

Lookup for the `__ui_*` API — human-facing, colored, TTY-aware. Machine records
use `__log_*` instead ([log-api.md](log-api.md)). The model is
[../explanation/output-model.md](../explanation/output-model.md); the palette
decision is [ADR-0009](../decisions/ADR-0009-single-palette-source-of-truth.md).

Commands that must work both at a terminal and from a graphical launcher should
require `lib/interact.bash` and use `interact::*` instead of calling `__ui_*`,
rofi, or `notify-send` directly. `BEBASH_UI=auto|tty|gui|none` controls mode
(`none` = silent: no terminal output, no notifications — for running a command
purely as an exit-code probe); `BEBASH_UI_LABEL` and `BEBASH_UI_ICON` control
notification identity.

## Message helpers (→ stderr)

| Function            | Prefix    | Role                                  |
| ------------------- | --------- | ------------------------------------- |
| `__ui_err  <msg>`   | `error:`  | An error, for a human. Red.           |
| `__ui_warn <msg>`   | `warning:`| A warning. Yellow.                    |
| `__ui_info <msg>`   | `info:`   | Progress / status. Cyan.              |
| `__ui_ok   <msg>`   | `✓`       | Success. Green.                       |
| `__ui_hint <msg>`   | `↳`       | A follow-up suggestion. Dim.          |

All write to **stderr** so they never pollute a piped/redirected result on
stdout. Color is applied only when `__ui_use_color 2` says so.

## Structure helpers

| Function                        | Role                                        |
| ------------------------------- | ------------------------------------------- |
| `__ui_head <title>`             | Section header (bold cyan).                 |
| `__ui_status <role> <msg>`      | A status line in a named palette role.      |
| `__ui_field <width> <label> <v>`| Aligned `label  value` row (for tables).    |
| `__ui_confirm <question> [-y]`  | Yes/no prompt. See return codes below.      |

## The palette (`__UI_SGR`)

One associative array is the single source of every color's *meaning*:

| Role     | SGR       | Used for                    |
| -------- | --------- | --------------------------- |
| `error`  | `31` red  | errors                      |
| `warn`   | `33` yellow | warnings                  |
| `info`   | `36` cyan | progress/status            |
| `ok`     | `32` green| success                     |
| `head`   | `1;36`    | section headers             |
| `accent` | `35` magenta | highlights               |
| `muted`  | `2` dim   | hints, de-emphasis          |
| `reset`  | `0`       | reset                       |

No ANSI is written outside this palette. A function wanting a new color extends
`__UI_SGR` rather than inlining an escape.

## Color gating: `__ui_use_color [fd]`

Returns success (color on) or failure (color off) for the given fd (default `1`)
using this precedence:

| Precedence | Condition                                   | Result   |
| ---------- | ------------------------------------------- | -------- |
| 1 (highest)| `NO_COLOR` set (any value)                  | **off**  |
| 2          | `FORCE_COLOR` / `CLICOLOR_FORCE` set        | **on**   |
| 3          | fd is a TTY (`[[ -t <fd> ]]`)               | on       |
| 4 (lowest) | otherwise (piped/redirected)                | off      |

The palette is resolved **per call**, never cached at load, so the same function
is colored at a TTY and plain when piped. See <https://no-color.org/>.

## Force-color for child renderers

A renderer whose stdout is a pipe into a UI (e.g. an `fzf` preview) still wants
color. It sources `ui.bash` and sets `FORCE_COLOR=1` in that scope, so
`__ui_use_color` returns "on" despite the non-TTY stdout.

## `__ui_confirm` return codes

| Code | Meaning                                             |
| ---- | --------------------------------------------------- |
| `0`  | Proceed (user said yes, or `-y/--yes` was passed).  |
| `1`  | Declined (user said no).                            |
| `2`  | No TTY and no `--yes` — cannot prompt; caller must fail loudly. |

Never hand-roll a `[y/N]` read; always route through `__ui_confirm` so the
non-interactive contract (code `2`) is honored uniformly
([output-channels.md](output-channels.md)).

## Sources

- No Color: <https://no-color.org/>
- CLI guidelines (output): <https://clig.dev/#output>
