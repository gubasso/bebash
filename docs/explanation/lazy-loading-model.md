# The lazy-loading model

Why bebash starts fast no matter how much it ships, and what deliberately loads
eagerly anyway. For the registry API see
[../reference/module-and-loader.md](../reference/module-and-loader.md).

## The problem lazy loading solves

A framework that `source`s every function, helper, and lib at shell startup pays
for all of it on every new terminal — even though a session typically calls only
a handful. As the shipped surface grows, eager loading turns into visible startup
lag. bebash avoids that by *registering* code cheaply and *sourcing* it only on
first use.

## Registration vs execution

At startup, most files are **registered**, not run:

- A **function** file becomes a tiny stub. The stub, on first call, sources the
  real file (replacing itself) and re-invokes with the original arguments. From
  the caller's view it just works; the cost is one source, once, only if called.
- A **lib** file becomes a registry *record*. It isn't sourced at
  startup at all. A command that needs it calls `__bebash_require_lib <name>`,
  which sources it once (guarded) and no-ops thereafter.

This is a registry **keyed by kind** (`function` / `lib`) rather than a
function-only autoloader — the generalization decided in
[ADR-0007](../decisions/ADR-0007-lazy-autoload-registry-of-kinds.md). Startup cost
becomes "index the files," which is O(1) in the number of definitions, not "source
the files."

## What stays eager, and why

Not everything can be deferred. The output primitives and core helpers load
eagerly, before any registration or `rc.d/*`:

- `lib/log.bash`, `lib/ui.bash` — early code (dependency guards, `rc.d` modules)
  must be able to print an error or a status line the instant startup begins.
- `lib/helpers.bash` and the autoload registry itself — the machinery that makes
  registration possible.

These files are small and side-effect-free until called, so loading them eagerly
costs almost nothing. The rule is [ADR-0010](../decisions/ADR-0010-eager-load-output-libs-before-helpers.md):
a lazy framework still needs an eager spine.

## Why not `command_not_found_handle`

Bash offers `command_not_found_handle`, which could source a lib the first time
any of its commands is invoked. bebash avoids it: that hook fires for *every*
unknown command, adding overhead and muddying real "command not found" errors.
Explicit stubs (for functions) and an explicit `__bebash_require_lib` (for libs)
are just as lazy and far more legible.

## The startup budget, in one line

Eager: three tiny libs + a registry pass over filenames. Deferred: every function
body, every optional lib. First call to a given function pays one source; every
later call is free. Measure before optimizing further — real startup cost usually
lives in external tool init (direnv, zoxide), not in sourcing bebash's own files.
