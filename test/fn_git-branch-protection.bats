setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/log.bash
  source lib/ui.bash
  source lib/helpers.bash
  source lib/autoload.bash
  __autoload_register lib git_branch_protection "$PWD/lib/git_branch_protection.bash"
  source functions/git-branch-protection.bash
  export BEBASH_LIB="$PWD"
  export BEBASH_DATA_DIR="$BATS_TEST_TMPDIR/data"
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

stub_gh_apply() {
  cat >"$bindir/gh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  api)
    shift
    if [[ "${1:-}" == "/repos/owner/repo/installation" ]]; then
      printf '4242\n'
      exit 0
    fi
    if [[ "${1:-}" == "-X" && "${2:-}" == "POST" && "${3:-}" == "/repos/owner/repo/rulesets" ]]; then
      mkdir -p "$GH_CAPTURE_DIR"
      count_file="$GH_CAPTURE_DIR/count"
      count=0
      [[ -r "$count_file" ]] && count=$(<"$count_file")
      count=$((count + 1))
      printf '%s\n' "$count" >"$count_file"
      cat >"$GH_CAPTURE_DIR/payload-$count.json"
      printf '{"id":%s,"name":"ok"}\n' "$count"
      exit 0
    fi
    ;;
  repo)
    [[ "${2:-}" == "edit" ]] && exit 0
    ;;
  ruleset)
    case "${2:-}" in
      list) printf 'rulesets\n'; exit 0 ;;
      check) printf 'check %s\n' "${3:-}"; exit 0 ;;
    esac
    ;;
esac

printf 'unexpected gh call:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 64
EOS
  chmod +x "$bindir/gh"
}

assert_valid_json_output() {
  printf '%s' "$output" | jq -e . >/dev/null
}

@test "git-branch-protection help" {
  run git-branch-protection -h
  assert_success
  assert_output --partial 'Usage:'

  run git-branch-protection --help
  assert_success
  assert_output --partial 'Usage:'
}

@test "git-branch-protection usage errors" {
  run git-branch-protection forge owner/repo
  assert_failure 2
  assert_output --partial 'unknown provider'

  run git-branch-protection gh
  assert_failure 2
  assert_output --partial 'missing target'

  run git-branch-protection glab group/project lookup
  assert_failure 2
  assert_output --partial 'GitLab lookup is not supported'
}

@test "git-branch-protection applies native GitHub rulesets" {
  stub_gh_apply
  export GH_CAPTURE_DIR="$BATS_TEST_TMPDIR/native-gh"

  run git-branch-protection --json gh owner/repo apply --required-checks ci/test
  assert_success
  assert_valid_json_output

  jq -e '.conditions.ref_name.include == ["~DEFAULT_BRANCH"]' "$GH_CAPTURE_DIR/payload-1.json" >/dev/null
  jq -e '.bypass_actors == [{"actor_id":4242,"actor_type":"Integration","bypass_mode":"always"}]' "$GH_CAPTURE_DIR/payload-1.json" >/dev/null
  jq -e '.bypass_actors == []' "$GH_CAPTURE_DIR/payload-2.json" >/dev/null
  jq -e '.bypass_actors == [{"actor_id":4242,"actor_type":"Integration","bypass_mode":"always"}]' "$GH_CAPTURE_DIR/payload-3.json" >/dev/null
  jq -e 'any(.rules[]; .type == "required_status_checks" and .parameters.required_status_checks == [{"context":"ci/test"}])' "$GH_CAPTURE_DIR/payload-1.json" >/dev/null
  jq -e 'any(.rules[]; .type == "required_status_checks" and .parameters.required_status_checks == [{"context":"ci/test"}])' "$GH_CAPTURE_DIR/payload-2.json" >/dev/null
  jq -e 'all(.rules[]; .type != "required_status_checks")' "$GH_CAPTURE_DIR/payload-3.json" >/dev/null
}

@test "git-branch-protection overlay rulesets override native rulesets" {
  stub_gh_apply
  export GH_CAPTURE_DIR="$BATS_TEST_TMPDIR/overlay-gh"
  overlay="$BEBASH_DATA_DIR/artifacts/git-branch-protection/rulesets"
  mkdir -p "$overlay"
  cp artifacts/git-branch-protection/rulesets/master.json "$overlay/master.json"
  cp artifacts/git-branch-protection/rulesets/develop.json "$overlay/develop.json"
  cp artifacts/git-branch-protection/rulesets/tags.json "$overlay/tags.json"
  jq '.name = "overlay-master-protection"' "$overlay/master.json" >"$overlay/master.json.tmp"
  mv "$overlay/master.json.tmp" "$overlay/master.json"

  run git-branch-protection --json gh owner/repo apply
  assert_success
  assert_valid_json_output

  jq -e '.name == "overlay-master-protection"' "$GH_CAPTURE_DIR/payload-1.json" >/dev/null
}

@test "git-branch-protection JSON string escapes C0 controls" {
  __bebash_require_lib git_branch_protection

  run __git_branch_protection_json_string $'bad\x01value'
  assert_success
  printf '%s' "$output" | jq -e . >/dev/null
  [[ "$output" == *'\u0001'* ]]
}
