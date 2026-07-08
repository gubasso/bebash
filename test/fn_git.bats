setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/git.bash
  bindir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
}

@test "__git_forge detects github" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
printf 'git@github.com:owner/repo.git\n'
EOS
  chmod +x "$bindir/git"
  run __git_forge origin
  assert_success
  assert_output github
}

@test "__git_forge detects gitlab and none" {
  cat >"$bindir/git" <<'EOS'
#!/usr/bin/env bash
case "$3" in
  lab) printf 'https://gitlab.example.com/o/r.git\n' ;;
  *) printf 'ssh://git@example.org/o/r.git\n' ;;
esac
EOS
  chmod +x "$bindir/git"
  run __git_forge lab
  assert_success
  assert_output gitlab
  run __git_forge other
  assert_success
  assert_output none
}
