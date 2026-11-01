setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
  source lib/helpers.bash
  source lib/autoload.bash
  source functions/gpr.bash
  __autoload_register lib git "$PWD/lib/git.bash"
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "gpr help" {
  run gpr -h
  assert_success
  assert_output --partial 'usage:'
}

@test "gpr branch path uses git" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GIT_CALLS"
EOS
  chmod +x "$bindir/git"
  export GIT_CALLS="$bindir/calls"
  run gpr --branch feature
  assert_success
  assert_file_contains "$GIT_CALLS" 'fetch origin'
  assert_file_contains "$GIT_CALLS" 'switch --track -c feature origin/feature'
}

@test "gpr missing gh reports dependency" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
printf 'git@github.com:owner/repo.git\n'
EOS
  chmod +x "$bindir/git"
  # Only the stub directory is on PATH, so a gh of the host, such as
  # /usr/bin/gh on a CI runner, cannot satisfy the dependency.
  ln -s "$(command -v bash)" "$bindir/bash"
  PATH="$bindir" run gpr 1
  assert_failure
  assert_output --partial 'Missing dependencies'
}
