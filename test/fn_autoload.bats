setup() {
  load 'test_helper/common-setup'
  _common_setup
  bats_require_minimum_version 1.5.0
  source lib/ui.bash
  source lib/autoload.bash
}

@test "function stub sources and reinvokes with args once" {
  local dir file count
  dir="$(mktemp -d)"
  count="$dir/count"
  file="$dir/demo.bash"
  cat >"$file" <<EOS
# shellcheck shell=bash
: 'desc: demo'
demo() { printf x >>"$count"; printf '%s:%s\\n' "\$1" "\$2"; }
EOS
  __autoload_register function demo "$file"
  run demo a b
  assert_success
  assert_output "a:b"
  run demo c d
  assert_success
  assert_output "c:d"
  [ "$(cat "$count")" = xx ]
}

@test "broken source returns non-zero without loop" {
  local file
  file="$(mktemp)"
  printf '%s\n' '# shellcheck shell=bash' 'this is broken' >"$file"
  __autoload_register function broken "$file"
  run -127 broken
  assert_failure
}

@test "require lib returns 69 for unknown and sources known once" {
  run __bebash_require_lib missing
  assert_failure 69
  local dir file count
  dir="$(mktemp -d)"
  count="$dir/count"
  file="$dir/known.bash"
  cat >"$file" <<EOS
# shellcheck shell=bash
: 'desc: known'
[[ -n "\${__bebash_known_loaded:-}" ]] && return 0
__bebash_known_loaded=1
printf x >>"$count"
EOS
  __autoload_register lib known "$file"
  __bebash_require_lib known
  __bebash_require_lib known
  [ "$(cat "$count")" = x ]
}

@test "scan dir registers bash files" {
  local dir
  dir="$(mktemp -d)"
  cat >"$dir/one.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: one'
one() { printf 'one\n'; }
EOS
  __autoload_scan_dir function "$dir"
  run one
  assert_success
  assert_output one
}
