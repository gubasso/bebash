setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "init-user scaffolds documented overlay dirs" {
  run_bebash init-user
  [ "$status" -eq 0 ]
  [ "$output" = "$XDG_CONFIG_HOME/bebash" ]
  [ -d "$XDG_CONFIG_HOME/bebash/functions" ]
  [ -d "$XDG_CONFIG_HOME/bebash/lib" ]
  [ -d "$XDG_CONFIG_HOME/bebash/rc.d" ]
  [ -d "$XDG_CONFIG_HOME/bebash/disabled.d" ]
  [ -f "$XDG_CONFIG_HOME/bebash/config.bash" ]
}

@test "init-user is idempotent and preserves config" {
  run_bebash init-user
  [ "$status" -eq 0 ]
  printf '%s\n' '# sentinel' >>"$XDG_CONFIG_HOME/bebash/config.bash"

  run_bebash init-user
  [ "$status" -eq 0 ]
  grep -qx '# sentinel' "$XDG_CONFIG_HOME/bebash/config.bash"
}
