setup() {
  load 'test_helper/common-setup'
  _common_setup
  source lib/ui.bash
}

@test "color gating honors NO_COLOR and FORCE_COLOR" {
  NO_COLOR=1 run __ui_use_color 1
  assert_failure
  unset NO_COLOR
  FORCE_COLOR=1 run __ui_use_color 1
  assert_success
}

@test "confirm returns 2 without tty and 0 with yes" {
  run __ui_confirm "x?"
  assert_failure 2
  run __ui_confirm "x?" --yes
  assert_success
}
