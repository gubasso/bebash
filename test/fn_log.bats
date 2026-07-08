setup() {
  load 'test_helper/common-setup'
  _common_setup
  export XDG_STATE_HOME
  XDG_STATE_HOME="$(mktemp -d)"
  source lib/log.bash
}

@test "info is suppressed by default and emitted at info threshold" {
  __log_info hidden
  [ ! -e "$XDG_STATE_HOME/bebash/bebash.log" ]
  BEBASH_LOG_LEVEL=info __log_info hello k=v
  run grep 'level=info' "$XDG_STATE_HOME/bebash/bebash.log"
  assert_success
  assert_output --partial 'msg="hello"'
}

@test "logfmt shape includes utc timestamp and key values" {
  BEBASH_LOG_LEVEL=debug __log_debug 'hello "there"' op=test
  run grep -E '^ts=[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z level=debug msg="hello \\"there\\"" op=test$' "$XDG_STATE_HOME/bebash/bebash.log"
  assert_success
}
