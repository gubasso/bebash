<!-- bebash-agent-doc-version: 1 -->

# bebash Overlay

This directory is a user overlay for bebash. The authoritative, always-current
source of truth is the installed CLI; use the commands below and do not rely on
this pointer file for detailed behavior.

```bash
bebash path
bebash man
bebash help <cmd>
bebash doctor --json
bebash list
```

## Conventions

- Function files live under `functions/`.
- Function files start with `# shellcheck shell=bash`.
- Line 2 is `: 'desc: ...'`.
- One public function per file.
- Function filename matches the public function name.
- User libs live under `lib/` and use `__bebash_<name>_loaded`.
- Startup snippets live under `rc.d/`.
- Standalone commands live under `commands/` and are executable.
- Run `bebash doctor` to validate the overlay.

## Paths

Get exact paths from:

```bash
bebash path
```

The full repository `docs/` shelf is intentionally not shipped into this
overlay. Use `bebash man`, `bebash help <cmd>`, and `bebash doctor` for the
local reference.
