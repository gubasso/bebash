# Guide: Adding a CLI subcommand

How to extend the `bebash` management CLI (the secondary surface —
[architecture](../explanation/architecture.md)). Conventions are specified in
[../reference/cli-conventions.md](../reference/cli-conventions.md) and
[../reference/module-and-loader.md](../reference/module-and-loader.md).

## 1. One file per subcommand

Create `lib/commands/cmd_<name>.bash`. The filename encodes the command so the
loader sources it on dispatch without a lookup table. Namespace the public
function and add a `desc:` marker:

```bash
# shellcheck shell=bash
: 'desc: Show resolved bebash paths.'

bebash::cmd::path() {
  __bebash_parse_common "$@" || return
  # ... do the work, results to stdout ...
}
```

## 2. Register the dispatch arm

Add the command to the dispatch table in `lib/core.bash` so `bebash path …` routes
to `cmd_path.bash`. Dispatch is explicit (no auto-discovery, no plugin registry):
the loader maps `bebash <name>` → `lib/commands/cmd_<name>.bash` → `bebash::cmd::<name>`.
An unknown command exits `2` (usage error).

## 3. Follow the output and exit contract

- Result data → stdout, plain and parseable; add `--json` if a machine consumes
  it ([output-channels](../reference/output-channels.md)).
- Status/errors/prompts → `__ui_*` on stderr.
- Exit codes per [../reference/exit-codes.md](../reference/exit-codes.md): `0` ok,
  `2` usage error, sysexits for specific failures.
- Honor `--yes`/`--non-interactive`; fail loudly when stdin isn't a TTY and a
  prompt would be required.

## 4. Help is generated, not hand-written

Usage/flags come from the parser plus the `desc:` marker; keep any authored prose
(examples, env vars, see-also) around the generated body, not duplicating the
flag table ([cli-conventions](../reference/cli-conventions.md)).

## 5. Test and document

Add `test/cmd_<name>.bats` ([testing](../reference/testing.md)). If the command
is user-facing enough to warrant it, add a line to the man page source
(`man/bebash.1.scd`). Run `just lint` and `just test`.
