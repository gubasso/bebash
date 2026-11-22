# Reference: Tooling

Lint, format, hooks, editor config, and dev environment for bebash. All checks run
through the hook runner prek, which the host supplies; never invoke linters
directly.

## Strict mode

Executable scripts (`bin/bebash`, `install*.sh`) open with:

```bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true   # bash 4.4+
```

Sourced library files start with `# shellcheck shell=bash` and **no** shebang.
Use `printf` over `echo`; quote expansions (`"$@"`, `"${arr[@]}"`); never set a
global `IFS=$'\n\t'`.

## `.shellcheckrc`

```text
external-sources=true
source-path=SCRIPTDIR
source-path=SCRIPTDIR/lib
source-path=SCRIPTDIR/libexec
source-path=SCRIPTDIR/functions
source-path=SCRIPTDIR/rc.d
shell=bash
disable=SC1091
```

Cross-file `source`s get an explicit `# shellcheck source=<path>` directive or
rely on `source-path`. Any `# shellcheck disable=SCxxxx` carries a one-line
justification.

## shfmt

Canonical flags: `shfmt -i 2 -ci -bn -s` (2-space indent, switch-case indent,
binary ops at line start, simplify).

`bebash doctor` reuses the same shellcheck configuration and exact shfmt flags
when optional tools are present. It runs those external tools over user artifacts
only; repository-owned payload lint remains gated by `just lint`.

## `.pre-commit-config.yaml` hooks

Hook types installed: `pre-commit`, `commit-msg`, `pre-push`
(`default_install_hook_types`). The shell file set (referenced as *shell files*
below) is `bin/*`, `lib/**/*.bash`, `libexec/**/*.bash`,
`functions/**/*.bash`, `rc.d/**/*.bash`, `install*.sh`, `uninstall.sh`, and
`test/**/*.bash`.

| Hook                 | Tool                 | Scope                              |
| -------------------- | -------------------- | ---------------------------------- |
| check-yaml           | prek built-in        | `*.yaml`, `*.yml`                  |
| check-toml           | prek built-in        | `*.toml` (`cliff.toml`, `committed.toml`) |
| end-of-file-fixer    | prek built-in        | all except the generated files     |
| trailing-whitespace  | prek built-in        | all except the generated files (`--markdown-linebreak-ext=md`) |
| housekeeping         | prek built-in        | check-merge-conflict, check-case-conflict, check-added-large-files, detect-private-key, check-executables-have-shebangs, check-shebang-scripts-are-executable |
| no-commit-to-branch  | prek built-in        | protects `master` (written only by CI, ADR-0015); `develop` stays writable; group `local-only` |
| editorconfig-checker | editorconfig-checker | all except `*.md` (owned by markdown tooling) and the generated files (`.editorconfig-checker.json`); final newlines owned by end-of-file-fixer; `LICENSE` exempt |
| shellcheck           | shellcheck-py (`-x`) | shell files                        |
| shfmt                | pre-commit-shfmt     | shell files                        |
| shellharden          | local (system)       | shell files (`--replace`, auto-quote) |
| bashate              | openstack/bashate    | executable scripts only — `bin/bebash`, `install*.sh`, `uninstall.sh` (`-i E003,E006`; sourced libs carry no shebang, so bashate does not run over them) |
| gitleaks             | gitleaks             | repo secret scan (pre-commit stage) |
| typos                | crate-ci/typos       | all except the generated files (report-only; allowlist and exclusions in `_typos.toml`) |
| committed            | crate-ci/committed   | commit-msg — Conventional Commits (ADR-0013); config `committed.toml` |
| markdown lint/format | markdownlint-cli2    | `docs/**/*.md` (fenced blocks need a language); built on the node of the devshell |
| test-unit            | local (bats)         | pre-commit stage                   |
| test-integration     | local (bats)         | pre-push stage                     |
| test-bash-versions   | local (bats)         | pre-push stage; the whole suite under bash 4.4, 5.0, and 5.2 |
| no-language-library-in-flake | local (pygrep) | `flake.nix`: the flake holds no language library |
| no-path-flake-reference | exobrain-tech     | a flake reference reads the git tree, never a `path:` copy |
| no-hook-runner-in-flake | exobrain-tech     | `flake.nix`: the devshell holds no hook runner |
| host-requirements    | exobrain-tech        | `host-requirements.toml` parses (`exobrain host-check --parse-only`) |
| hook-revisions       | exobrain-tech        | the `rev` of each shared hook repository follows the exobrain-tech tag |

The built-in hooks run inside prek: no clone, no environment, and no `rev`. A
configuration with `repo: builtin` runs under prek only.

exobrain-tech publishes reference hook sets, one per stack. bebash takes the
`common`, `bash`, and `nix` sets as an offer: it keeps only the hooks it runs,
with its own `args`, `stages`, `files`, and `exclude`. `hook-revisions` reads
only the `rev`. It compares the `rev` of each repository that both this
configuration and the named sets hold, at the tag of the exobrain-tech entry,
and fails on a difference. `exobrain hooks sync --to <tag>` moves that tag and
every shared `rev` together, so nobody edits a shared `rev` by hand.

Vendored bats helper libraries (`test/test_helper/bats-*`, pinned upstream) are
excluded from the housekeeping, editorconfig-checker, shellcheck, shellharden,
and bashate hooks — they carry upstream style and findings bebash does not own.

A generated file follows its generator. git-cliff writes `CHANGELOG.md` from
`cliff.toml`, and nix writes `flake.lock`. Both keep their generator's form:
`just release` commits the changelog exactly as git-cliff writes it, and no hook
rewrites or judges either file. end-of-file-fixer and trailing-whitespace
exclude them in their `exclude:`, because those hooks have no configuration of
their own. typos excludes them in `_typos.toml`, and editorconfig-checker in
`.editorconfig-checker.json`, so a direct run of either tool agrees with the
hook. The hooks that only read a file, such as the conflict and secret checks,
still read them. `cliff.toml` stays the project's own template: git-cliff
expects one, and no check depends on it.
`typos` runs report-only: it never rewrites deliberate identifiers (`__ui_*` /
`__log_*` namespaces, `err.kind` strings); fix real typos by hand and allowlist
false positives in `_typos.toml`. `committed` is the local enforcement of the
Conventional Commits contract the release flow (ADR-0013/0017) already assumes.

## Hook stages and CI

Two rules bind the hooks. A push that passed the local hooks passes CI, so the
pre-commit and pre-push stages together run every check of CI. The pre-push
stage runs no hook of the pre-commit stage, and it holds the costly checks.
[ADR-0036](../decisions/ADR-0036-hooks-hold-every-ci-check.md) records the
decision.

| Stage      | Hooks                                                    | Local command | CI job |
| ---------- | -------------------------------------------------------- | ------------- | ------ |
| pre-commit | every lint hook, and `test-unit`                         | `just lint`   | `lint` |
| pre-push   | `test-integration`, `test-bash-versions`                 | `just test`   | `test` |
| commit-msg | `committed`                                              | —             | —      |

`default_stages: [pre-commit]` keeps a hook with no `stages` out of the
pre-push stage. An upstream manifest that names its own `stages` wins over that
default, so each such hook sets `stages: [pre-commit]` in
`.pre-commit-config.yaml`.

A hook that one runtime cannot run belongs to a prek group, with a comment
above it that states why. The group `local-only` holds the hooks that CI
cannot run: `no-commit-to-branch` judges a local commit, and CI makes none. A
CI-only hook would take `stages: [manual]` and the group `ci-only`. bebash has
none.

The native commands of the two stages, which `just lint` and `just test` run:

```bash
nix develop --command prek run --all-files
nix develop --command prek run --all-files --hook-stage pre-push
```

The CI jobs run the same stages without the group `local-only`. A group filter
with no `--stage` also runs the `manual` hooks, so each CI step names its stage:

```bash
nix develop --command prek run --all-files --stage pre-commit --no-group local-only
nix develop --command prek run --all-files --stage pre-push --no-group local-only
```

Each CI job that runs the hooks installs the `exobrain` CLI of the release that
the exobrain-tech entry pins, and verifies its attestation, because
`hook-revisions` and `host-requirements` call it.

`test-bash-versions` runs `nix build` for the packages `bats-bash-4_4`,
`bats-bash-5_0`, and `bats-bash-5_2` of `flake.nix`. Each package holds a bash
built from its GNU tarball and a bats whose shebangs point at that bash. The
first push builds them, and the Nix store keeps them.

CI-only checks: none. Report-only jobs: none. The `release` workflow runs the
`ci` workflow on a tag, then builds and publishes the release. It adds no check
of the code. CI has no commit-message check: `committed` runs only in the local
`commit-msg` hook.

## `.editorconfig`

```text
root = true
[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
[*.{sh,bash,bats}]
indent_style = space
indent_size = 2
[*.{json,yaml,yml,toml}]
indent_style = space
indent_size = 2
[justfile]
indent_style = tab
[*.md]
trim_trailing_whitespace = false
```

## Nix dev shell

A `flake.nix` pins the devshell (bash, shellharden, just, bats, jq,
yq, scdoc/mandoc, node, git-cliff) so `nix develop --command just lint` is
reproducible.

Each tool has one owner, the most specific file that declares that kind of tool
natively. bebash has no package manifest, because Bash has none.
`.pre-commit-config.yaml` pins each hook tool for which the hook runner builds an
environment: shellcheck, shfmt, bashate, editorconfig-checker, gitleaks, typos,
committed, and markdownlint-cli2. The devshell holds bash, the language of the
project, the task runner, each tool that no hook can build, such
as `shellharden` and `bats`, and the `node` on which the hook runner builds the
`markdownlint-cli2` hook (`default_language_version` sets `node: system`). The
host supplies `nix`, `direnv`, `git`, the hook runner `prek`, the `exobrain`
CLI, the base tools, and the tools that carry credentials, such as `gh`. The
devshell holds no hook runner and no `exobrain`, because a devshell copy comes
first on the `PATH` and hides the host tool. `host-requirements.toml` declares
the host tools that the recipes and hooks run, and each recipe checks its tools
in its first line with `exobrain host-check`. `.envrc` runs two warnings of
the `exobrain` CLI, `exobrain outdated` and `exobrain store-guard --daily`.
Each exits 0 and changes nothing. A hook that keeps `language: system` carries an
`# owner:` comment with its owner, class, and reason.

## Markdown rule

Every fenced code block must declare a language (markdownlint MD040); use `text`
when none applies. This shelf follows that rule.

## Sources

- ShellCheck directives: <https://github.com/koalaman/shellcheck/wiki/Directive>
- shfmt: <https://github.com/mvdan/sh>
- prek: <https://prek.j178.dev/>
