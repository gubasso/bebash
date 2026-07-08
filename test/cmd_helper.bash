# shellcheck shell=bash
: 'desc: shared setup for bebash CLI tests'

cmd_setup() {
  local name=${BATS_TEST_NAME//[^A-Za-z0-9_]/_}
  export BEBASH_LIB="$BATS_TEST_DIRNAME/.."
  export PATH="$BEBASH_LIB/bin:$PATH"
  export TMPDIR="$BEBASH_LIB/test/tmp/$name"
  export XDG_CONFIG_HOME="$TMPDIR/config home"
  export XDG_STATE_HOME="$TMPDIR/state"
  export XDG_DATA_HOME="$TMPDIR/data"
  rm -rf -- "$TMPDIR"
  mkdir -p -- "$TMPDIR" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"
}

run_bebash() {
  run "$BEBASH_LIB/bin/bebash" "$@"
}
