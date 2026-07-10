# Guide: Creating a user overlay

Layer your own functions, config, and modules on top of the shipped base without
editing (or losing on upgrade) any shipped file. The precedence rules are
specified in
[../reference/overlay-precedence.md](../reference/overlay-precedence.md); the
concept is in [../explanation/overlay-model.md](../explanation/overlay-model.md).

## 1. Scaffold the overlay

```bash
bebash init-user
```

This creates the overlay skeleton, split by XDG role. Your *code* lives under the
data root `~/.local/share/bebash/` (`$BEBASH_DATA_DIR`); your *config* under the
config root `~/.config/bebash/` (`$BEBASH_CONFIG_DIR`):

```text
~/.local/share/bebash/     # your code (data root)
├── functions/         # your functions (registered after shipped → they win)
├── lib/               # your libs (available via __bebash_require_lib)
├── rc.d/              # your startup modules (sourced after shipped rc.d)
└── commands/          # your standalone executables (bebash puts this dir on PATH)

~/.config/bebash/          # your config (config root)
├── config.bash        # your env, options, project shortcuts (sourced last)
└── disabled.d/        # names of shipped functions to suppress
```

## 2. Add a personal function

Drop a file named for the function, same format as a shipped one:

```bash
# ~/.local/share/bebash/functions/deploy.bash
# shellcheck shell=bash
: 'desc: Deploy the current project.'

deploy() { __ui_info "deploying…"; : ; }
```

New shell → `deploy` is available, lazy-loaded like any shipped function.

## 3. Override a shipped function

Create a file with the **same name** as the shipped one. Because your overlay
registers last, your version wins — no config needed:

```bash
# ~/.local/share/bebash/functions/gpr.bash  → replaces the shipped gpr
```

## 4. Disable a shipped function

To remove rather than replace, list its name in `disabled.d/`:

```bash
touch ~/.config/bebash/disabled.d/slug   # unsets the shipped `slug`
```

## 5. Set config and personal shortcuts

Put knobs and personal shortcuts in `config.bash` (sourced last, so it can read
env vars and define functions). The base ships only generic tooling — anything that
needs a personal target lives entirely in your overlay
([ADR-0026](../decisions/ADR-0026-retire-tier-2-parameterized-mechanism.md)). A
project-shortcut setup, for example, is yours to own end to end: a helper lib under
`lib/`, the functions under `functions/`, and the roots in `config.bash`:

```bash
# ~/.local/share/bebash/lib/project.bash   → your reusable helper (loaded via
#                                             __bebash_require_lib project)
__project_nvim() { cd "$2" && command nvim "${@:3}"; }

# ~/.config/bebash/config.bash
PROJECT_ROOTS=("${PROJECTS:-$HOME/Projects}")               # env-driven, your own key
docs()  { __bebash_require_lib project && __project_nvim docs  "$HOME/Documents" "$@"; }
notes() { __bebash_require_lib project && __project_nvim notes "$HOME/Notes" "$@"; }
```

See [../reference/config-and-xdg.md](../reference/config-and-xdg.md) for every
shipped config key and its default.

## 6. Keep the overlay in your own dotfiles

The overlay dir is a normal directory; you can also make it the deploy target of
a Stow package so your personal setup is tracked in your dotfiles:

```text
dotfiles-package/bebash/.config/bebash/        -> ~/.config/bebash/
dotfiles-package/bebash/.local/share/bebash/   -> ~/.local/share/bebash/
```

bebash only ever reads the XDG config and data roots; the deploy step is yours.
This is how personal Tier-3 functions stay out of the public base while
remaining available to you ([overlay model](../explanation/overlay-model.md)).
