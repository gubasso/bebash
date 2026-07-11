<!-- bebash-user-readme-version: 1 -->

# bebash User Overlay

This overlay holds your bebash configuration and user-owned extensions.

Useful commands:

```bash
bebash path
bebash list
bebash edit --new my-function
bebash doctor
bebash man
```

Typical layout:

```text
config.bash       user configuration loaded by bebash
disabled.d/       disabled function markers
AGENTS.md         lean agent pointer to the CLI reference
README.md         this file
functions/        user functions
lib/              user helper libraries
rc.d/             user startup snippets
commands/         executable standalone commands
```

Run `bebash path` for the exact config and data roots on this machine.
