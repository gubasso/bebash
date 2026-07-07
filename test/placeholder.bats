# STUB — DELETE ME. Temporary placeholder so the `test-unit` pre-commit hook
# (bats --recursive --filter-tags '!integration' test) has something to run
# before the real suite exists. Self-contained on purpose: it must NOT load the
# bats-support/assert/file submodule helpers, which are not vendored yet.
#
# Replace with real fn_*.bats / cmd_*.bats tests per docs/reference/testing.md,
# then remove this file and test/README.md.

@test "placeholder: bats harness runs" {
  run true
  [ "$status" -eq 0 ]
}
