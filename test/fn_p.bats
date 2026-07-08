setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source lib/functions/p.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "p help" {
  run p -h
  assert_success
  assert_output --partial 'usage:'
}

@test "p defaults to HOME Projects" {
  HOME="$(mktemp -d)"
  mkdir -p "$HOME/Projects/repo/.git"
  cat >"$bindir/fd" <<'EOS'
#!/usr/bin/env bash
last=
for arg in "$@"; do last=$arg; done
printf '%s/repo/.git\n' "$last"
EOS
  cat >"$bindir/fzf" <<'EOS'
#!/usr/bin/env bash
cat
EOS
  chmod +x "$bindir/fd" "$bindir/fzf"
  run bash -c 'source lib/ui.bash; source lib/helpers.bash; source lib/functions/p.bash; p; pwd'
  assert_success
  assert_output --partial "$HOME/Projects/repo"
}
