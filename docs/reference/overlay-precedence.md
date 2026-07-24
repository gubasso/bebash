# Reference: Overlay precedence

The exact directory map and load order that make user files win over shipped
ones. Concept: [../explanation/overlay-model.md](../explanation/overlay-model.md);
decision: [ADR-0022](../decisions/ADR-0022-overlay-config-vs-data-split.md)
(supersedes [ADR-0005](../decisions/ADR-0005-payload-vs-xdg-user-overlay.md)).

## Directory map

The user overlay is split by XDG role: *code* lives under the data root
`~/.local/share/bebash/`, true *config* under the config root `~/.config/bebash/`.

| Concern            | Shipped payload (clobbered)      | User overlay (never clobbered)          |
| ------------------ | -------------------------------- | --------------------------------------- |
| Code root          | `$PREFIX/lib/bebash/`            | `~/.local/share/bebash/`                |
| Config root        | —                                | `~/.config/bebash/`                     |
| Entry / config     | `init.bash`                     | `config.bash` (in config root, sourced last) |
| Functions          | `functions/<n>.bash`        | `functions/<n>.bash` (wins)             |
| Libs               | `lib/<n>.bash`                  | `lib/<n>.bash` (augments)               |
| Startup modules    | `rc.d/NN-*.bash`            | `rc.d/*.bash` (added after)             |
| Commands           | —                                | `commands/<name>` (put on `PATH` by shipped `rc.d/15-commands-path.bash`) |
| Command artifacts  | `$PREFIX/lib/bebash/artifacts/<command>/...` | `~/.local/share/bebash/artifacts/<command>/...` (explicitly resolved data; not on `PATH`) |
| Disable list       | —                                | `disabled.d/<name>` (in config root)    |

bebash reads user code from `~/.local/share/bebash/` and user config from
`~/.config/bebash/`, regardless of whether those directories are plain
directories or symlinks managed by a separate dotfiles tool
([overlay model](../explanation/overlay-model.md)).

Command-owned artifacts use an explicit resolver, not the autoload pipeline:
commands resolve overlay artifacts first, native artifacts second, and never
merge partial artifact subtrees.

## Load order (`init.bash`)

```text
1. resolve BEBASH_LIB (payload), BEBASH_DATA_DIR (user code), BEBASH_CONFIG_DIR (user config)
2. EAGER core:   source log → ui → helpers → autoload registry
3. register SHIPPED functions        (stubs)         ← from $BEBASH_LIB/functions
4. register SHIPPED libs               (records)
5. source SHIPPED rc.d/*.bash         (lexical order)
6. register USER functions            (stubs, replace shipped of same name) ← $BEBASH_DATA_DIR
7. register USER libs
8. source USER rc.d/*.bash             ← $BEBASH_DATA_DIR
9. source USER config.bash             ← $BEBASH_CONFIG_DIR
10. apply disabled.d/*                (unset -f each named function)
```

## Why user wins

Registration order decides the winner. Shipped functions register at step 3; user
functions register at step 6. Because a later stub definition replaces an earlier
one of the same name, the user's `gpr.bash` shadows the shipped `gpr` with no
configuration. This is the same mechanic as oh-my-bash's `custom/` overlay
([inspiration-projects.md](inspiration-projects.md)).

## Override, extend, disable

| Goal                       | Do this                                                  |
| -------------------------- | -------------------------------------------------------- |
| Replace a shipped function | Add `functions/<same-name>.bash` to the overlay.         |
| Add a new function         | Add `functions/<new-name>.bash`.                         |
| Add startup behavior       | Add `rc.d/NN-<topic>.bash` (runs after shipped modules). |
| Change config / shortcuts  | Set keys in `config.bash` ([config-and-xdg.md](config-and-xdg.md)). |
| Remove a shipped function  | `touch disabled.d/<name>` — step 10 unsets it.           |

## `disabled.d/` format

- One file per function to suppress; the **filename is the function name**
  (`disabled.d/slug`). A `.bash` suffix, if present, is stripped, so `slug` and
  `slug.bash` both mask `slug`.
- Step 10 runs `unset -f <name>` for each entry, removing the function (or its
  autoload stub) after all registration is done. It does not touch variables.
- A name that matches nothing is silently ignored (masking is declarative, not an
  assertion). File contents are unused — only the name matters.

## Guarantees

- An upgrade recopies the payload but never reads or writes the overlay, so user
  content always survives.
- Overrides need no registration call or config — same filename, loaded later.
- `disabled.d/` runs last, so it can suppress a shipped function even if an
  overlay file re-registered it.
