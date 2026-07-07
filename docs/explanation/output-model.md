# The output model

How bebash code talks to the world, and why it is split three ways. For exact
signatures see [../reference/ui-api.md](../reference/ui-api.md),
[../reference/log-api.md](../reference/log-api.md), and the channel matrix in
[../reference/output-channels.md](../reference/output-channels.md).

## Three audiences

Before printing a line, ask *who reads it?* There are three answers, each with
its own surface:

| Audience                         | Surface        | Stream / sink                | Colored? |
| -------------------------------- | -------------- | ---------------------------- | -------- |
| A human at a terminal            | `__ui_*`       | stderr (status), stdout (UI) | yes      |
| The command's actual result data | plain `printf` | stdout                       | no       |
| A machine: agent, script, debug  | `__log_*`      | log file                     | never    |

- **Human UX** (`lib/ui.bash`): errors, warnings, progress, prompts, previews,
  summaries — anything a person eyeballs.
- **Result data** (plain stdout): the thing the command exists to produce — a
  list of branches, a resolved path. Must stay parseable (`| jq`, `> file`).
- **Machine log** (`lib/log.bash`): structured events for post-mortems and coding
  agents. Off the terminal by default; opt-in verbosity.

## Stream discipline

The split maps onto Unix streams:

- **stdout** carries the *result* — data a caller pipes or redirects. A colored
  status line here breaks `cmd | jq` and `cmd > file`, so keep it plain.
- **stderr** carries everything else meant for a *human*: progress, warnings,
  errors, prompts. The `__ui_*` helpers write here.
- **the log file** carries *machine* records. `__log_*` writes here (default
  `$XDG_STATE_HOME/bebash/bebash.log`), never to stdout.

## Why reserve `__log_*` for machines

If one namespace served both humans and machines, every consumer would strip or
add formatting, and stdout would stop being a clean pipe. Reserving `__log_*` for
`key=value` machine records — no ANSI, no prose — keeps the boundary greppable
and each surface honest. This is
[ADR-0008](../decisions/ADR-0008-reserve-log-namespace-for-machines.md).

## Why color is gated, not constant

Color helps a human read a terminal; it is noise (or breakage) anywhere else. So
color is emitted only when it helps: on an interactive TTY, forced when a caller
asks (`FORCE_COLOR`/`CLICOLOR_FORCE`, e.g. an `fzf` preview pipe), and never when
`NO_COLOR` is set or output is redirected. The precedence is
`NO_COLOR > FORCE_COLOR > isatty`. The palette itself lives in one place
(`__UI_SGR`) so a color's *meaning* is consistent everywhere — this is
[ADR-0009](../decisions/ADR-0009-single-palette-source-of-truth.md). The exact
precedence table is in [../reference/ui-api.md](../reference/ui-api.md).

## Where this is enacted

`lib/ui.bash` and `lib/log.bash` load eagerly, before the rest, so the primitives
are available to early `rc.d/*` code and to dependency guards — see
[ADR-0010](../decisions/ADR-0010-eager-load-output-libs-before-helpers.md) and
[architecture.md](architecture.md).
