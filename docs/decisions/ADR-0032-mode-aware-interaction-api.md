# ADR-0032: Provide a mode-aware interaction API

## Context and Problem Statement

Standalone commands can run from a terminal or from a graphical launcher. If each
command hand-rolls `[[ -t 0 ]]`, rofi, and notifications, behavior diverges and
commands either spam terminals with notifications or silently fail in launchers.

## Considered Options

- Keep prompting and feedback entirely in user overlays.
- Add a framework `interact::*` API for mode detection, prompts, feedback, and
  gate helpers.
- Force all standalone commands to be terminal-only.

## Decision Outcome

Chosen option: **framework `interact::*` API**. `lib/interact.bash` exposes
`interact::mode`, `is_tty`, `is_gui`, `msg`, `password`, `confirm`, `pick`,
`pick_multi`, `require_tty`, and `require_gui`. `BEBASH_UI=auto|tty|gui`
selects mode, while `BEBASH_UI_LABEL` and `BEBASH_UI_ICON` shape GUI
notifications. Terminal mode writes through `__ui_*`; GUI mode uses rofi for
input and `notify-send` for feedback.

Autoload scans framework libs before overlay libs, then overlay registration
wins for future `__bebash_require_lib interact` calls. During migration, both
copies share `__bebash_interact_loaded`; whichever copy is required first defines
the namespace and the other no-ops.

## Consequences

- Good: commands can be launcher-safe without wrapper preludes, and authors can
  gate terminal-only or GUI-only paths consistently.
- Bad: GUI prompting depends on rofi and a graphical session; missing tools are
  reported as interaction errors.

## Status

Implemented — enacted by `lib/interact.bash` and covered by `fn_interact.bats`.
