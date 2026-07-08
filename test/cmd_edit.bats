setup() {
  load 'cmd_helper'
  cmd_setup
}

@test "edit without EDITOR exits 69" {
  unset EDITOR
  run bash -c '"$BEBASH_LIB/bin/bebash" edit gpr >"$TMPDIR/stdout"'
  [ "$status" -eq 69 ]
  [ ! -s "$TMPDIR/stdout" ]
}

@test "edit missing function without --new exits 2" {
  export EDITOR=true
  run_bebash edit new_fn
  [ "$status" -eq 2 ]
}

@test "edit --new scaffolds overlay function and opens editor" {
  local editor="$TMPDIR/editor"
  cat >"$editor" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$EDITOR_SEEN"
EOS
  chmod +x "$editor"
  export EDITOR="$editor" EDITOR_SEEN="$TMPDIR/seen"

  run bash -c '"$BEBASH_LIB/bin/bebash" edit --new new_fn >"$TMPDIR/stdout"'
  [ "$status" -eq 0 ]
  [ ! -s "$TMPDIR/stdout" ]
  [ "$(cat "$EDITOR_SEEN")" = "$XDG_CONFIG_HOME/bebash/functions/new_fn.bash" ]
  grep -q 'new_fn()' "$XDG_CONFIG_HOME/bebash/functions/new_fn.bash"
}
