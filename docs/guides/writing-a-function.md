# Guide: Writing a function

How to add a shipped function to bebash. The rules referenced here are specified
in [../reference/module-and-loader.md](../reference/module-and-loader.md),
[../reference/ui-api.md](../reference/ui-api.md), and
[../reference/conventions.md](../reference/conventions.md).

## 1. One file, one function

Create `functions/<name>.bash`. The filename **is** the function name, so the
autoloader can register it without a lookup table. Start with the shell directive
and a self-describing `desc:` marker on line 2:

```bash
# shellcheck shell=bash
: 'desc: Delete local branches whose upstream is gone.'

git-branch-gone() {
  local force=0 yes=0
  # ... parse flags, do the work ...
}
```

The `desc:` line is harvested by `bebash list` and the help generator with a
cheap `grep`; it costs nothing at startup.

## 2. Route output to the right surface

Pick the audience for every line
([output model](../explanation/output-model.md)):

- Human status, errors, prompts → `__ui_err`, `__ui_warn`, `__ui_info`,
  `__ui_ok`, `__ui_confirm` (these go to stderr, colored when appropriate).
- The command's real result → plain `printf '%s\n'` to **stdout**, parseable.
- Machine/debug events → `__log_info`/`__log_warn`/… (structured, to the log
  file). Add these for destructive or long operations.

Never hardcode ANSI or hand-roll a `[y/N]` read — draw from `__UI_SGR` and
`__ui_confirm` ([ADR-0009](../decisions/ADR-0009-single-palette-source-of-truth.md)).

## 3. Pull in libs on demand

If you need a shared lib, require it inside the function so startup stays lazy:

```bash
git-branch-gone() {
  __bebash_require_lib git || return
  # ...
}
```

## 4. Guard dependencies and flags

- Guard external tools with `__require_verbose <cmd>…` (reports each missing tool
  via `__ui_err`, returns non-zero).
- Support `-h/--help` (print usage from a reusable `__<name>_usage`, exit `0`) and
  `-y/--yes` (skip confirmation). Unknown flags → `__ui_err` + exit `2`.
- Use the exit-code contract in
  [../reference/exit-codes.md](../reference/exit-codes.md).

## 5. Test it

Add `test/fn_<name>.bats` (see [../reference/testing.md](../reference/testing.md)).
Cover help, the happy path, an error path, and non-interactive refusal if it
prompts.

## 6. Check before shipping

Run the pre-ship checklist in
[../reference/conventions.md](../reference/conventions.md#pre-ship-checklist) and
`just lint`. If the function is generic, it ships in the base; if it hardcodes
personal paths, parameterize it or keep it in your overlay
([privacy tiers](../reference/privacy-tiers.md)).
