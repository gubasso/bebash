# Reference: Overlay precedence

The exact directory map and load order that make user files win over shipped
ones. Concept: [../explanation/overlay-model.md](../explanation/overlay-model.md);
decision: [ADR-0005](../decisions/ADR-0005-payload-vs-xdg-user-overlay.md).

## Directory map

| Concern            | Shipped payload (clobbered)      | User overlay (never clobbered)          |
| ------------------ | -------------------------------- | --------------------------------------- |
| Root               | `$PREFIX/lib/bebash/`            | `~/.config/bebash/`                     |
| Entry / config     | `init.bash`                     | `config.bash` (sourced last)            |
| Functions          | `lib/functions/<n>.bash`        | `functions/<n>.bash` (wins)             |
| Libs               | `lib/<n>.bash`                  | `lib/<n>.bash` (augments)               |
| Startup modules    | `lib/rc.d/NN-*.bash`            | `rc.d/*.bash` (added after)             |
| Disable list       | —                                | `disabled.d/<name>`                     |

For the author, the overlay dir is the stow target of `~/.dotfiles/bebash/`;
bebash only reads `~/.config/bebash/` ([overlay model](../explanation/overlay-model.md)).

## Load order (`init.bash`)

```text
1. resolve BEBASH_LIB (payload) and BEBASH_CONFIG_DIR (overlay)
2. EAGER core:   source log → ui → helpers → autoload registry
3. register SHIPPED functions        (stubs)         ← from $BEBASH_LIB/lib/functions
4. register SHIPPED libs/modules      (records)
5. source SHIPPED rc.d/*.bash         (lexical order)
6. register USER functions            (stubs, replace shipped of same name) ← overlay
7. register USER libs/modules
8. source USER rc.d/*.bash
9. source USER config.bash
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
  (`disabled.d/zup`). A `.bash` suffix, if present, is stripped, so `zup` and
  `zup.bash` both mask `zup`.
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
