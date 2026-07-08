setup() {
  load 'test_helper/common-setup'
  _common_setup
}

@test "init load order, overlay wins, disabled unsets" {
  local payload overlay result
  payload="$(mktemp -d)"
  overlay="$(mktemp -d)"
  result="$payload/result"
  mkdir -p "$payload/lib/functions" "$payload/lib/rc.d" "$overlay/functions" "$overlay/disabled.d"
  cp init.bash "$payload/init.bash"
  cp -R lib "$payload/lib_src"
  cp "$payload/lib_src"/log.bash "$payload/lib/"
  cp "$payload/lib_src"/ui.bash "$payload/lib/"
  cp "$payload/lib_src"/helpers.bash "$payload/lib/"
  cp "$payload/lib_src"/autoload.bash "$payload/lib/"
  rm -rf "$payload/lib_src"
  cat >"$payload/lib/functions/gpr.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: shipped'
gpr() { printf 'shipped\n'; }
EOS
  cat >"$overlay/functions/gpr.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: overlay'
gpr() { printf 'overlay\n'; }
EOS
  cat >"$payload/lib/rc.d/00-probe.bash" <<EOS
# shellcheck shell=bash
: 'desc: probe'
declare -F gpr >/dev/null && printf 'stub-before-rc\\n' >>"$result"
EOS
  touch "$overlay/disabled.d/disabled"
  cat >"$payload/lib/functions/disabled.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: disabled'
disabled() { printf 'bad\n'; }
EOS

  run bash -c "BEBASH_LIB='$payload' BEBASH_CONFIG_DIR='$overlay' source '$payload/init.bash'; gpr; declare -F disabled >/dev/null || printf 'disabled-unset\n'"
  assert_success
  assert_output --partial overlay
  assert_output --partial disabled-unset
  [ "$(cat "$result")" = stub-before-rc ]
}
