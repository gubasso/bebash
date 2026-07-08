setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "init-user scaffolds documented config and data dirs" {
  run_bebash init-user
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "config=$XDG_CONFIG_HOME/bebash" ]
  [ "${lines[1]}" = "data=$XDG_DATA_HOME/bebash" ]
  [ -d "$XDG_CONFIG_HOME/bebash/disabled.d" ]
  [ -f "$XDG_CONFIG_HOME/bebash/config.bash" ]
  [ -d "$XDG_DATA_HOME/bebash/functions" ]
  [ -d "$XDG_DATA_HOME/bebash/lib" ]
  [ -d "$XDG_DATA_HOME/bebash/rc.d" ]
  [ -d "$XDG_DATA_HOME/bebash/commands" ]
}

@test "init-user is idempotent and preserves config" {
  run_bebash init-user
  [ "$status" -eq 0 ]
  printf '%s\n' '# sentinel' >>"$XDG_CONFIG_HOME/bebash/config.bash"

  run_bebash init-user
  [ "$status" -eq 0 ]
  grep -qx '# sentinel' "$XDG_CONFIG_HOME/bebash/config.bash"
}
