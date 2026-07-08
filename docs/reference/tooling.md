# Reference: Tooling

Lint, format, hooks, editor config, and dev environment for bebash. All checks run
through pre-commit; never invoke linters directly.

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

## `.pre-commit-config.yaml` hooks

Hook types installed: `pre-commit`, `commit-msg`, `pre-push`
(`default_install_hook_types`). The shell file set (referenced as *shell files*
below) is `bin/*`, `lib/**/*.bash`, `libexec/**/*.bash`,
`functions/**/*.bash`, `rc.d/**/*.bash`, `install*.sh`, `uninstall.sh`, and
`test/**/*.bash`.

| Hook                 | Tool                 | Scope                              |
| -------------------- | -------------------- | ---------------------------------- |
| check-yaml           | pre-commit-hooks     | `*.yaml`, `*.yml`                  |
| check-toml           | pre-commit-hooks     | `*.toml` (`cliff.toml`, `committed.toml`) |
| end-of-file-fixer    | pre-commit-hooks     | all                                |
| trailing-whitespace  | pre-commit-hooks     | all (`--markdown-linebreak-ext=md`) |
| housekeeping         | pre-commit-hooks     | check-merge-conflict, check-case-conflict, check-added-large-files, detect-private-key, check-executables-have-shebangs, check-shebang-scripts-are-executable |
| no-commit-to-branch  | pre-commit-hooks     | protects `master` (CI-only, ADR-0015); `develop` stays writable |
| editorconfig-checker | editorconfig-checker | all except `*.md` (owned by markdown tooling); final newlines owned by end-of-file-fixer; `LICENSE` exempt |
| shellcheck           | shellcheck-py (`-x`) | shell files                        |
| shfmt                | pre-commit-shfmt     | shell files                        |
| shellharden          | local (system)       | shell files (`--replace`, auto-quote) |
| bashate              | openstack/bashate    | executable scripts only — `bin/bebash`, `install*.sh`, `uninstall.sh` (`-i E003,E006`; sourced libs carry no shebang, so bashate does not run over them) |
| gitleaks             | gitleaks             | repo secret scan (pre-commit stage) |
| typos                | crate-ci/typos       | all (report-only; allowlist in `_typos.toml`) |
| committed            | crate-ci/committed   | commit-msg — Conventional Commits (ADR-0013); config `committed.toml` |
| markdown lint/format | markdown tooling     | `docs/**/*.md` (fenced blocks need a language) |
| test-unit            | local (bats)         | pre-commit stage                   |
| test-integration     | local (bats)         | pre-push stage                     |

Vendored bats helper libraries (`test/test_helper/bats-*`, pinned upstream) are
excluded from the housekeeping, editorconfig-checker, shellcheck, shellharden,
and bashate hooks — they carry upstream style and findings bebash does not own.
`typos` runs report-only: it never rewrites deliberate identifiers (`__ui_*` /
`__log_*` namespaces, `err.kind` strings); fix real typos by hand and allowlist
false positives in `_typos.toml`. `committed` is the local enforcement of the
Conventional Commits contract the release flow (ADR-0013/0017) already assumes.

(No skill/agent-linting hooks — those belong to a different project, not bebash.)

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

## Nix dev shell (optional)

A `flake.nix` pins the toolchain (bash, shellcheck, shfmt, shellharden, just,
pre-commit, bats, jq, yq, git, scdoc/mandoc, markdown tooling, git-cliff) so
`nix develop --command just lint` is reproducible. `shellharden` backs the
`language: system` pre-commit hook, alongside the local bats hooks.

## Markdown rule

Every fenced code block must declare a language (markdownlint MD040); use `text`
when none applies. This shelf follows that rule.

## Sources

- ShellCheck directives: <https://github.com/koalaman/shellcheck/wiki/Directive>
- shfmt: <https://github.com/mvdan/sh>
- pre-commit: <https://pre-commit.com/>
