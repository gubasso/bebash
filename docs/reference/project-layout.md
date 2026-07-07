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
│   ├── autoload.bash           # lazy registry (function/lib/module kinds)
│   ├── helpers.bash            # __require, __cached_init, path helpers (eager)
│   ├── ui.bash                 # __ui_* human output + __UI_SGR palette (eager)
│   ├── log.bash                # __log_* machine logs (eager)
│   ├── git.bash                # git helpers (lazy, load-guarded)
│   ├── project.bash            # __project_nvim mechanism (lazy)
│   ├── commands/               # one file per CLI subcommand
│   │   └── cmd_<name>.bash      # defines bebash::cmd::<name>
│   ├── functions/              # shipped user-facing functions (lazy)
│   │   └── <name>.bash          # defines <name>; filename == function name
│   ├── rc.d/                   # startup modules, sourced in lexical order
│   │   └── NN-<topic>.bash
│   └── templates/              # scaffolds for `bebash edit --new` / init-user
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
├── LICENSE · README.md · VERSION
└── .github/workflows/          # CI + release-please
```

## Directory roles

| Path             | Role                                                                 |
| ---------------- | ------------------------------------------------------------------- |
| `bin/`           | Thin CLI shim only — no logic; resolves symlinks, sources, dispatches. |
| `init.bash`      | Framework entry point; the file `~/.bashrc` sources.                |
| `lib/`           | Shared machinery sourced by both the framework and the CLI.         |
| `lib/commands/`  | CLI-only subcommand handlers (`bebash::cmd::*`).                     |
| `lib/functions/` | Library functions exposed to interactive shells (lazy-loaded).      |
| `lib/rc.d/`      | Startup modules (options, tool integrations), lexical order, guarded. |
| `lib/templates/` | Scaffolds emitted by the CLI (`init-user`, `edit --new`).           |
| `completions/`   | Shell completion for the CLI.                                        |
| `man/`           | scdoc man-page source, built by `just man`.                         |
| `test/`          | bats-core suite; `fn_*` = library, `cmd_*` = CLI.                    |
| `docs/`          | Documentation shelf (this tree).                                    |

## File extensions

One rule (specified in [conventions.md](conventions.md#file-extensions)): files
**sourced** into the shell or CLI runtime use `.bash` (no shebang;
`# shellcheck shell=bash`); the **executed** top-level scripts `install.sh` /
`uninstall.sh` use `.sh`; the `bin/bebash` entry point has no extension. So the
CLI machinery (`core.bash`, `loader.bash`, `commands/cmd_*.bash`) is `.bash` like
every other sourced file; `install-common.sh` is `.sh` because it belongs to the
executed installer family.

## The framework/CLI split

`lib/functions/` is the **library** surface — things a sourced shell should have.
`lib/commands/` is the **CLI** surface — things you invoke as `bebash <name>`.
Shared helpers live directly in `lib/`. Keeping the two apart is
[ADR-0003](../decisions/ADR-0003-dual-nature-framework-and-cli.md); the module
rules for both are in [module-and-loader.md](module-and-loader.md).

## Install-time mapping

The `lib/` tree, `bin/bebash`, `completions/`, `man/`, `init.bash`, and `VERSION`
are copied into the payload at `$PREFIX/lib/bebash/` (with the CLI symlinked onto
`PATH`). `docs/`, `test/`, and repo tooling are **not** installed. Exact targets
and the manifest are in
[installer-and-manifest.md](installer-and-manifest.md).
