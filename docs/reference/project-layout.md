# Reference: Project layout

The repository tree and the role of each directory. Conceptual context is in
[../explanation/architecture.md](../explanation/architecture.md).

## Repository tree

```text
bebash/
├── bin/
│   └── bebash                  # thin CLI shim: resolve → source core → dispatch
├── init.bash                   # framework entry point (sourced from ~/.bashrc)
├── lib/
│   ├── core.bash               # bebash::main, global flags, subcommand dispatch
│   ├── loader.bash             # source-on-dispatch resolver for CLI commands
│   ├── autoload.bash           # lazy registry (function/lib kinds)
│   ├── helpers.bash            # __require, __cached_init, path helpers (eager)
│   ├── ui.bash                 # __ui_* human output + __UI_SGR palette (eager)
│   ├── log.bash                # __log_* machine logs (eager)
│   ├── git.bash                # git helpers (lazy, load-guarded)
├── libexec/
│   └── commands/               # one file per CLI subcommand
│       └── cmd_<name>.bash      # defines bebash::cmd::<name>
├── functions/                  # shipped user-facing functions (lazy)
│   └── <name>.bash              # defines <name>; filename == function name
├── rc.d/                       # startup modules, sourced in lexical order
│   └── NN-<topic>.bash
├── templates/                  # scaffolds for `bebash edit --new` / init-user
├── completions/
│   └── bebash.bash             # bash completion for the CLI
├── man/
│   └── bebash.1.scd            # scdoc source → bebash.1
├── test/
│   ├── test_helper/            # bats-support / bats-assert / bats-file submodules
│   │   └── common-setup.bash
│   ├── cmd_*.bats              # CLI subcommand tests
│   └── fn_*.bats               # library function tests
├── docs/                       # this shelf (Diátaxis zones)
├── justfile                    # install / uninstall / lint / test / dist / man
├── install.sh                  # executed installer (top-level entry script)
├── install-common.sh           # sourced by install.sh / uninstall.sh (shared helpers)
├── uninstall.sh                # executed uninstaller (reads the manifest)
├── cliff.toml                  # git-cliff changelog config
├── .shellcheckrc · .editorconfig · .pre-commit-config.yaml
├── flake.nix · flake.lock      # Nix dev shell (optional)
├── LICENSE · README.md
├── VERSION                     # committed X.Y.Z; authoring source of truth
└── .github/workflows/          # CI + tag-triggered release (git-cliff)
```

## Directory roles

- `bin/` — Executables: the `bebash` CLI shim self-locates its library root,
  sources, and dispatches; it contains no command logic. On install it is copied
  as a real file into `$PREFIX/bin`; the payload keeps no `bin/` subdir
  ([ADR-0025](../decisions/ADR-0025-real-fhs-bin-with-dual-layout-self-location.md)).
- `init.bash` — Framework entry point; the file `~/.bashrc` sources.
- `init-headless.bash` — Non-interactive loader a standalone command sources to
  reach the framework without the interactive `rc.d` layer
  ([ADR-0024](../decisions/ADR-0024-bebash-owns-commands-path-lane.md)).
- `lib/` — Shared machinery sourced by both the framework and the CLI.
- `libexec/commands/` — CLI-only subcommand handlers (`bebash::cmd::*`).
- `functions/` — Library functions exposed to interactive shells
  (lazy-loaded).
- `rc.d/` — Startup modules (options, tool integrations), lexical order,
  guarded.
- `templates/` — Scaffolds emitted by the CLI (`init-user`, `edit --new`).
- `completions/` — Shell completion for the CLI.
- `man/` — scdoc man-page source, built by `just man`.
- `test/` — bats-core suite; `fn_*` = library, `cmd_*` = CLI.
- `docs/` — Documentation shelf (this tree).

## File extensions

One rule (specified in [conventions.md](conventions.md#file-extensions)): files
**sourced** into the shell or CLI runtime use `.bash` (no shebang;
`# shellcheck shell=bash`); the **executed** top-level scripts `install.sh` /
`uninstall.sh` use `.sh`; the `bin/bebash` entry point has no extension. So the
CLI machinery (`core.bash`, `loader.bash`, `libexec/commands/cmd_*.bash`) is `.bash` like
every other sourced file; `install-common.sh` is `.sh` because it belongs to the
executed installer family.

## The framework/CLI split

`functions/` is the **library** surface — things a sourced shell should have.
`libexec/commands/` is the **CLI** surface — things you invoke as `bebash <name>`.
Shared helpers live directly in `lib/`. Keeping the two apart is
[ADR-0003](../decisions/ADR-0003-dual-nature-framework-and-cli.md) and
[ADR-0021](../decisions/ADR-0021-payload-fhs-role-split.md); loader rules are in
[module-and-loader.md](module-and-loader.md).

## Install-time mapping

The `lib/`, `libexec/`, `functions/`, `rc.d/`, and `templates/` trees plus
`init.bash`, `init-headless.bash`, and `VERSION` are copied into the payload at
`$PREFIX/lib/bebash/`; the `bin/bebash` script is installed as a real executable in
`$PREFIX/bin` (not into the payload). Completion and man files are installed
under XDG data targets, not copied into the payload.
`VERSION` is a committed file — the authoring source of truth
([release-workflow.md](release-workflow.md#version-source-of-truth),
[ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md)) — copied
into the payload like any other file. `docs/`, `test/`, and repo tooling are
**not** installed. Exact targets and the manifest are in
[installer-and-manifest.md](installer-and-manifest.md).
