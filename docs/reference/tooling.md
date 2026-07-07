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

| Hook                 | Tool                | Scope                              |
| -------------------- | ------------------- | ---------------------------------- |
| check-yaml           | pre-commit-hooks    | `*.yaml`, `*.yml`                  |
| end-of-file-fixer    | pre-commit-hooks    | all                                |
| trailing-whitespace  | pre-commit-hooks    | all                                |
| shellcheck           | shellcheck-py (`-x`) | `bin/bebash`, `lib/**/*.bash`, `install*.sh`, `uninstall.sh`, `test/*.bash` |
| shfmt                | pre-commit-shfmt    | same shell files                   |
| markdown lint/format | markdown tooling    | `docs/**/*.md` (fenced blocks need a language) |
| test-unit            | local (bats)        | pre-commit stage                   |
| test-integration     | local (bats)        | pre-push stage                     |

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
[justfile]
indent_style = tab
[*.md]
trim_trailing_whitespace = false
```

## Nix dev shell (optional)

A `flake.nix` pins the toolchain (bash, shellcheck, shfmt, just, pre-commit, bats,
jq, git, scdoc/mandoc, markdown tooling, git-cliff) so `nix develop --command just
lint` is reproducible.

## Markdown rule

Every fenced code block must declare a language (markdownlint MD040); use `text`
when none applies. This shelf follows that rule.

## Sources

- ShellCheck directives: <https://github.com/koalaman/shellcheck/wiki/Directive>
- shfmt: <https://github.com/mvdan/sh>
- pre-commit: <https://pre-commit.com/>
