setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/log.bash
  source lib/ui.bash
  source lib/helpers.bash
  source functions/md-create.bash
  bindir="$(mktemp -d)"
  workdir="$(mktemp -d)"
  export PATH="$bindir:$PATH"
  export BEBASH_LOG_FILE="$workdir/bebash.log"
  cd "$workdir"
}

@test "md-create help" {
  run md-create --help
  assert_success
  assert_output --partial 'usage: md-create'
}

@test "md-create requires a title" {
  run md-create
  assert_failure 2
  assert_output --partial 'usage: md-create'
}

@test "md-create creates slugified markdown file and prints path" {
  cat >"$bindir/slugify" <<'EOS'
#!/usr/bin/env bash
printf 'hello-world\n'
EOS
  chmod +x "$bindir/slugify"

  run md-create "Hello World"
  assert_success
  assert_output 'hello-world.md'
  assert_file_contains "$workdir/hello-world.md" '# Hello World'
}

@test "md-create existing file warns and returns path" {
  cat >"$bindir/slugify" <<'EOS'
#!/usr/bin/env bash
printf 'hello-world\n'
EOS
  chmod +x "$bindir/slugify"
  printf '# Existing\n' >"$workdir/hello-world.md"

  run md-create "Hello World"
  assert_success
  assert_output --partial 'hello-world.md'
  assert_file_contains "$workdir/hello-world.md" '# Existing'
}
