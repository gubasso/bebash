# Reference: Exit codes and errors

The exit-code contract and error-message shape for bebash commands and functions.

## The small set (functions and simple commands)

| Code | Meaning                                                    |
| ---- | ---------------------------------------------------------- |
| `0`  | Success.                                                   |
| `1`  | Operational failure (the work itself failed).              |
| `2`  | Usage error (bad flag, missing/duplicate arg, unknown cmd). |

Reserve `2` for "you called me wrong" so scripts can distinguish it from "the work
failed". A command with richer failure modes documents extra codes in a header
comment and draws them from the sysexits set below.

## sysexits (richer CLI failures)

For the `bebash` CLI, map distinct failures to stable
[sysexits(3)](https://man.freebsd.org/cgi/man.cgi?query=sysexits) codes and
unit-test the mapping:

| Code | Name            | When                                   |
| ---- | --------------- | -------------------------------------- |
| `64` | EX_USAGE        | wrong usage: bad flag, missing arg     |
| `65` | EX_DATAERR      | input data malformed                   |
| `66` | EX_NOINPUT      | input file missing/unreadable          |
| `69` | EX_UNAVAILABLE  | a required service/tool is unavailable  |
| `70` | EX_SOFTWARE     | internal bug / invariant broken        |
| `73` | EX_CANTCREAT    | could not create an output file        |
| `74` | EX_IOERR        | I/O error during execution             |
| `77` | EX_NOPERM       | permission denied                      |
| `78` | EX_CONFIG       | config file invalid                    |
| `128+N` | —             | killed by signal N (e.g. `130` = SIGINT). |

Avoid a bare catch-all `1` in the CLI when a specific code fits; interactive
library functions may use the small set above.

## Stable error kinds (`err.kind`)

Every distinct error gets a stable, machine-matchable `err.kind` that does not
change between versions (renaming one is a breaking change). It appears in the
log record (`err.kind=ConfigNotFound`) and, optionally, in the human message.
Agents and runbooks pattern-match on it. See [log-api.md](log-api.md).

## Error message anatomy (human)

A good human error answers four things, on stderr, via `__ui_err`/`__ui_hint`:

```text
error: failed to load overlay config
  where: ~/.config/bebash/config.bash (line 12)
  why:   BEBASH_LOG_LEVEL must be one of: debug info warn error
  hint:  set BEBASH_LOG_LEVEL=warn and retry
```

1. **what** — the operation that failed, one line;
2. **where** — the specific input/file/step;
3. **why** — the root cause;
4. **hint** — the next action (omit if unknown).

## Signals and temp state

Any script creating temp state cleans up on exit and common signals:

```bash
tmpdir="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmpdir"' EXIT
trap 'rm -rf "$tmpdir"; exit 130' INT
trap 'rm -rf "$tmpdir"; exit 143' TERM
```

## Sources

- sysexits(3): <https://man.freebsd.org/cgi/man.cgi?query=sysexits>
- CLI guidelines (errors): <https://clig.dev/#errors>
