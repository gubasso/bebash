setup() {
  load 'test_helper/common-setup'
  _common_setup
  export XDG_CACHE_HOME
  XDG_CACHE_HOME="$(mktemp -d)"
  source lib/ui.bash
  source lib/helpers.bash
}

@test "__path_prepend is idempotent" {
  local dir
  dir="$(mktemp -d)"
  # shellcheck disable=SC2030
  PATH="/usr/bin"
  __path_prepend "$dir"
  __path_prepend "$dir"
  [ "$PATH" = "$dir:/usr/bin" ]
}

@test "__is_graphical follows DISPLAY/WAYLAND_DISPLAY" {
  DISPLAY=":0" WAYLAND_DISPLAY="" __is_graphical
  DISPLAY="" WAYLAND_DISPLAY="wayland-0" __is_graphical
  run env -u DISPLAY -u WAYLAND_DISPLAY bash -c "source lib/ui.bash; source lib/helpers.bash; __is_graphical"
  [ "$status" -eq 1 ]
}

@test "__cached_init rebuilds when binary is newer" {
  local bindir marker
  bindir="$(mktemp -d)"
  marker="$bindir/marker"
  cat >"$bindir/fake-tool" <<'EOS'
#!/usr/bin/env bash
printf 'export FAKE_TOOL_VALUE=%s\n' "$(cat "$1")"
EOS
  chmod +x "$bindir/fake-tool"
  printf one >"$marker"
  # shellcheck disable=SC2031
  PATH="$bindir:$PATH" __cached_init fake-tool fake-tool "$marker"
  [ "$FAKE_TOOL_VALUE" = one ]
  printf two >"$marker"
  sleep 1
  touch "$bindir/fake-tool"
  # shellcheck disable=SC2031
  PATH="$bindir:$PATH" __cached_init fake-tool fake-tool "$marker"
  [ "$FAKE_TOOL_VALUE" = two ]
}
