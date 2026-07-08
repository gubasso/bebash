setup() {
  load 'test_helper/common-setup'
  _common_setup
}

@test "init load order, data wins, config disables" {
  local payload config data result
  payload="$(mktemp -d)"
  config="$(mktemp -d)"
  data="$(mktemp -d)"
  result="$payload/result"
  mkdir -p "$payload/functions" "$payload/rc.d" "$config/disabled.d" "$data/functions" "$payload/lib"
  cp init.bash "$payload/init.bash"
  cp lib/log.bash lib/ui.bash lib/helpers.bash lib/autoload.bash "$payload/lib/"
  cat >"$payload/functions/gpr.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: shipped'
gpr() { printf 'shipped\n'; }
EOS
  cat >"$data/functions/gpr.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: data'
gpr() { printf 'data\n'; }
EOS
  cat >"$payload/rc.d/00-probe.bash" <<EOS
# shellcheck shell=bash
: 'desc: probe'
declare -F gpr >/dev/null && printf 'stub-before-rc\\n' >>"$result"
EOS
  touch "$config/disabled.d/disabled"
  cat >"$payload/functions/disabled.bash" <<'EOS'
# shellcheck shell=bash
: 'desc: disabled'
disabled() { printf 'bad\n'; }
EOS

  run bash -c "BEBASH_LIB='$payload' BEBASH_CONFIG_DIR='$config' BEBASH_DATA_DIR='$data' source '$payload/init.bash'; gpr; declare -F disabled >/dev/null || printf 'disabled-unset\n'"
  assert_success
  assert_output --partial data
  assert_output --partial disabled-unset
  [ "$(cat "$result")" = stub-before-rc ]
}

@test "init ignores old config code dirs but sources config bash" {
  local payload config data
  payload="$(mktemp -d)"
  config="$(mktemp -d)"
  data="$(mktemp -d)"
  mkdir -p "$payload/functions" "$payload/rc.d" "$payload/lib" "$config/functions" "$config/lib" "$config/rc.d" "$data/functions"
  cp init.bash "$payload/init.bash"
  cp lib/log.bash lib/ui.bash lib/helpers.bash lib/autoload.bash "$payload/lib/"
  cat >"$config/config.bash" <<'EOS'
# shellcheck shell=bash
BEBASH_CONFIG_PROBE=loaded
EOS
  cat >"$config/functions/old_fn.bash" <<'EOS'
# shellcheck shell=bash
old_fn() { printf 'old\n'; }
EOS
  cat >"$config/rc.d/00-old.bash" <<'EOS'
# shellcheck shell=bash
BEBASH_OLD_RC=loaded
EOS

  run bash -c "BEBASH_LIB='$payload' BEBASH_CONFIG_DIR='$config' BEBASH_DATA_DIR='$data' source '$payload/init.bash'; printf '%s\n' \"\$BEBASH_CONFIG_PROBE\"; declare -F old_fn >/dev/null || printf 'old-fn-ignored\n'; printf '%s\n' \"\${BEBASH_OLD_RC:-old-rc-ignored}\""
  assert_success
  assert_output --partial loaded
  assert_output --partial old-fn-ignored
  assert_output --partial old-rc-ignored
}
