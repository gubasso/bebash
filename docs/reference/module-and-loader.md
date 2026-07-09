# Reference: Modules and the loader

The rules for how code files are shaped, named, registered, and loaded. Concept:
[../explanation/lazy-loading-model.md](../explanation/lazy-loading-model.md).

## One public function per file

| Path                       | Defines                | Visibility |
| -------------------------- | ---------------------- | ---------- |
| `functions/<name>.bash`| `<name>`               | public (library) |
| `libexec/commands/cmd_<name>.bash`| `bebash::cmd::<name>` | public (CLI) |
| `lib/<name>.bash`          | shared helpers/libs    | shared     |
| any file, `__<name>`       | private helper         | private (same file) |

Rules:

- The filename **is** the public name, so the loader derives the target without a
  lookup table.
- Sourced files carry `# shellcheck shell=bash` on line 1 (no shebang — they are
  sourced, not executed). Executables in `bin/` get `#!/usr/bin/env bash`: `bin/bebash`
  is the CLI shim, and standalone commands such as `bin/dots` are the third public lane
  ([../guides/adding-a-standalone-command.md](../guides/adding-a-standalone-command.md)).
- CLI functions are namespaced `bebash::cmd::<name>`; library functions use their
  bare command name; internal helpers use a `__` prefix.

## The `desc:` marker

Line 2 of every function/command file is a self-describing sentinel the help and
`bebash list` generators harvest with `grep`:

```bash
# shellcheck shell=bash
: 'desc: Delete local branches whose upstream is gone.'
```

It is a no-op at runtime, costs nothing at startup, and is the single source of
the one-line description shown in help and listings.

## The autoload registry (framework)

At startup `lib/autoload.bash` builds a registry **keyed by kind**
([ADR-0007](../decisions/ADR-0007-lazy-autoload-registry-of-kinds.md)):

| Call                                   | Effect                                                        |
| -------------------------------------- | ------------------------------------------------------------- |
| `__autoload_register function <n> <p>` | Define a stub `<n>` that sources `<p>` on first call, then re-invokes. |
| `__autoload_register lib <n> <p>`      | Record `<n>→<p>`; **not** sourced until required.             |
| `__bebash_require_lib <n>`             | Source lib `<n>` once (guarded); no-op if loaded. Returns `0` on success, `69` (EX_UNAVAILABLE) if `<n>` is not registered. |

Libs load only when a function asks for them:

```bash
gpr() { __bebash_require_lib git || return; …; }
```

### Function-stub mechanism

`__autoload_register function <n> <p>` defines a stub that, on first call,
replaces itself with the real function and re-invokes with the original
arguments — so callers never see the indirection and later calls have zero
overhead:

```bash
__autoload_register() {
  local kind="$1" name="$2" path="$3"
  case "$kind" in
    function)
      eval "$(printf '%s() { unset -f %s; source %q || return; %s "$@"; }' \
        "$name" "$name" "$path" "$name")" ;;
    lib) __BEBASH_REGISTRY["$kind:$name"]="$path" ;;   # record only
  esac
}
```

If the `source` fails (unreadable/syntax error), the stub returns that non-zero
status and does **not** re-invoke, so a broken file surfaces as an error rather
than an infinite loop. The real file must define a function of exactly `<name>`.

### `__bebash_require_lib <name>`

Pulls a registered `lib` on demand, exactly once:

- Looks up `lib:<name>` in the registry; if absent → `__ui_err` + return `69`.
- Sources the file behind a load guard so a repeated require is a cheap no-op.
- A syntax error in the lib propagates its non-zero status to the caller.

## Load guards

Every lazily-sourced lib is idempotent via a load guard at the top. The guard
variable is named `__bebash_<libname>_loaded` (mandatory, so `require` and direct
`source` are both cheap on repeat):

```bash
# shellcheck shell=bash
[[ -n ${__bebash_git_loaded:-} ]] && return   # lib name: git
__bebash_git_loaded=1
```

`__bebash_require_lib` relies on this so a double-require is cheap.

## The CLI loader (source-on-dispatch)

`lib/loader.bash` keeps CLI startup O(1): a subcommand file is sourced only when
that command runs.

```bash
bebash::loader::dispatch() {
  local sub="$1"; shift
  local path="${BEBASH_LIB}/libexec/commands/cmd_${sub}.bash"
  [[ -r "$path" ]] || bebash::die 2 "unknown command: ${sub}"
  # shellcheck source=/dev/null
  source "$path"
  "bebash::cmd::${sub}" "$@"
}
```

Dispatch is explicit — no auto-discovery, no plugin trait. Adding a command is a
new `cmd_<name>.bash` plus one dispatch arm in `lib/core.bash`
([adding a subcommand](../guides/adding-a-cli-subcommand.md)).

## What stays eager

`lib/log.bash`, `lib/ui.bash`, `lib/helpers.bash`, and the registry load before
any registration or `rc.d/*`
([ADR-0010](../decisions/ADR-0010-eager-load-output-libs-before-helpers.md)).
Everything else is deferred.
