# shellcheck shell=bash
: 'desc: shared bats setup for bebash tests'

_common_setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-file/load'

  # Hermetic git env: strip repo-local vars a pre-commit hook would export.
  local git_env_vars=()
  mapfile -t git_env_vars < <(git rev-parse --local-env-vars 2>/dev/null || :)
  ((${#git_env_vars[@]})) && unset "${git_env_vars[@]}"

  PATH="${BATS_TEST_DIRNAME}/../bin:$PATH"
}
