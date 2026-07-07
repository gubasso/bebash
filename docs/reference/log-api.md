# Reference: `lib/log.bash` (machine logs)

Lookup for the `__log_*` API — structured, machine-readable, never colored. The
`__log_*` name is **reserved** for this surface; human messages use `__ui_*`
([ui-api.md](ui-api.md)). Rationale:
[ADR-0008](../decisions/ADR-0008-reserve-log-namespace-for-machines.md).

## Functions

| Function                      | Level  |
| ----------------------------- | ------ |
| `__log_err   <msg> [k=v …]`   | error  |
| `__log_warn  <msg> [k=v …]`   | warn   |
| `__log_info  <msg> [k=v …]`   | info   |
| `__log_debug <msg> [k=v …]`   | debug  |
| `__log <level> <msg> [k=v …]` | (core) |

`<msg>` is quoted into `msg="…"`. Extra `key=value` tokens are appended verbatim,
so format them yourself (`op=git.fetch`, not `op = git.fetch`).

## Record format

One `key=value` record per line ([logfmt](https://brandur.org/logfmt)), no ANSI:

```text
ts=2026-07-07T12:41:08Z level=warn target=bebash::git op=branch.delete branch=feat/x status=ok dur_ms=12
```

Fields:

| Field     | Required | Meaning                                         |
| --------- | -------- | ----------------------------------------------- |
| `ts`      | yes      | ISO-8601 UTC (millisecond precision).           |
| `level`   | yes      | `error\|warn\|info\|debug` (lowercase).          |
| `target`  | when set | module path, e.g. `bebash::git`.                |
| `msg`     | if no `op` | short human string (≤80 chars).               |
| `op`      | optional | operation name, e.g. `git.fetch`.               |
| `status`  | optional | `ok\|error\|skip\|noop`.                         |
| `dur_ms`  | optional | duration, integer ms.                           |
| `err.kind`| on error | stable error code, e.g. `ConfigNotFound`.       |

Field names are short and stable; errors are fields, not prose; no multi-line
records (they break `grep` and cost tokens).

## Sink and mirroring

- Appended to `${XDG_STATE_HOME:-$HOME/.local/state}/bebash/bebash.log`
  (best-effort; silent on failure).
- Mirrored to stderr **only** when `BEBASH_LOG_STDERR` is set (non-empty).
- Never goes to stdout — stdout stays reserved for result data.
- Every `__log_*` call returns `0`: logging is best-effort and never changes the
  caller's exit status, even if the write or the log dir creation fails.

## Level gating

`BEBASH_LOG_LEVEL` (default `warn`) sets the threshold; records below it are
dropped and cost nothing.

| Level   | Rank | In the log by default? |
| ------- | ---- | ---------------------- |
| `error` | 40   | yes                    |
| `warn`  | 30   | yes                    |
| `info`  | 20   | no (opt-in)            |
| `debug` | 10   | no (opt-in)            |

## Environment

| Variable            | Effect                                               |
| ------------------- | ---------------------------------------------------- |
| `BEBASH_LOG_LEVEL`  | Minimum level written (default `warn`).              |
| `BEBASH_LOG_STDERR` | If non-empty, mirror every emitted record to stderr. |
| `BEBASH_LOG_FILE`   | Override the log path.                                |
| `XDG_STATE_HOME`    | Base of the log dir (default `~/.local/state`).      |

## Sources

- logfmt: <https://brandur.org/logfmt>
- XDG Base Directory: <https://specifications.freedesktop.org/basedir/latest/>
