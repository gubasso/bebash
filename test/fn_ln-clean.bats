setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/log.bash
  source lib/ui.bash
  source lib/helpers.bash
  source functions/ln-clean.bash
  sandbox="$(mktemp -d)"
  export BEBASH_LOG_FILE="$sandbox/bebash.log"
}

@test "ln-clean help" {
  run ln-clean -h
  assert_success
  assert_output --partial 'ln-clean - Find and remove broken symlinks'
}

@test "ln-clean list returns 0 when none are found" {
  run ln-clean list "$sandbox"
  assert_success
  assert_output --partial 'No broken symlinks found'
}

@test "ln-clean list returns 1 when broken links exist" {
  ln -s "$sandbox/missing" "$sandbox/broken"

  run ln-clean list "$sandbox"
  assert_failure 1
  assert_output --partial 'broken'
}

@test "ln-clean dry-run does not remove broken links" {
  ln -s "$sandbox/missing" "$sandbox/broken"

  run ln-clean rm --dry-run "$sandbox"
  assert_success
  [[ -L "$sandbox/broken" ]]
  assert_output --partial 'Would remove'
}

@test "ln-clean quiet remove deletes all broken links" {
  ln -s "$sandbox/missing" "$sandbox/broken"

  run ln-clean rm --quiet "$sandbox"
  assert_success
  assert_file_not_exists "$sandbox/broken"
}

@test "ln-clean interactive fallback fails loudly without tty" {
  ln -s "$sandbox/missing" "$sandbox/broken"
  bindir="$(mktemp -d)"
  cat >"$bindir/fzf" <<'EOS'
#!/usr/bin/env bash
exit 127
EOS
  chmod +x "$bindir/fzf"
  export PATH="$bindir:$PATH"

  run ln-clean rm "$sandbox"
  assert_failure 2
  assert_output --partial 'interactive selection requires a terminal'
}

@test "ln-clean option state does not leak between calls" {
  ln -s "$sandbox/missing" "$sandbox/broken"

  run ln-clean list --quiet "$sandbox"
  assert_failure 1
  run ln-clean list "$sandbox"
  assert_failure 1
  assert_output --partial 'Broken symlinks'
}

@test "ln-clean bad usage returns 2" {
  run ln-clean --unknown
  assert_failure 2
  assert_output --partial 'Unknown option'

  run ln-clean --depth nope
  assert_failure 2
  assert_output --partial 'Depth must be a non-negative integer'
}
