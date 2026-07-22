# Reference: Testing

How bebash is tested: [bats-core](https://github.com/bats-core/bats-core) with the
support/assert/file helper libraries and a hermetic git environment.

## Layout

```text
test/
├── test_helper/
│   ├── bats-support/        # git submodule
│   ├── bats-assert/         # git submodule
│   ├── bats-file/           # git submodule
│   └── common-setup.bash
├── fn_<name>.bats           # library-function tests
└── cmd_<name>.bats          # CLI-subcommand tests
```

Naming distinguishes the two surfaces: `fn_*` exercises `functions/`,
`cmd_*` exercises the `bebash` CLI. One test file per public function/command.

## `common-setup.bash`

```bash
_common_setup() {
  load 'bats-support/load'
  load 'bats-assert/load'
  load 'bats-file/load'

  # Hermetic git env: strip repo-local vars a pre-commit hook would export.
  local git_env_vars=()
  mapfile -t git_env_vars < <(git rev-parse --local-env-vars 2>/dev/null || :)
  ((${#git_env_vars[@]})) && unset "${git_env_vars[@]}"

  PATH="${BATS_TEST_DIRNAME}/../bin:$PATH"
}
```

The git-env sanitization is essential: git hooks export `GIT_DIR`,
`GIT_INDEX_FILE`, etc. into the hook process, which otherwise leak into tests run
from pre-commit and make them fail. `git rev-parse --local-env-vars` is git's own
authoritative list.

## A test

```bash
setup() {
  load 'test_helper/common-setup'
  _common_setup
}

@test "git-branch-sync -h prints usage and exits 0" {
  run git-branch-sync -h
  assert_success
  assert_output --partial 'usage:'
}
```

## What to cover per function

- `-h/--help` prints usage, exits `0`.
- The happy path produces the expected stdout result.
- An error path returns a specific non-zero code ([exit-codes.md](exit-codes.md)).
- If it prompts, non-interactive-without-`--yes` fails loudly (return `2`), and
  `--yes` proceeds.

## Running

Via `just` (which drives pre-commit stages):

```bash
just test         # unit + integration
just lint         # shellcheck + shfmt + markdown
```

CI runs the suite across bash `4.4`, `5.0`, `5.2` with `submodules: recursive`.
See [tooling.md](tooling.md).
