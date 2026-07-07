# Reference: Inspiration projects

Prior art bebash borrows from, and the specific idea taken from each. bebash is
its own design; this records provenance and where to look for deeper patterns.

## Borrow-from map

| Project | URL | Borrow this |
| ------- | --- | ----------- |
| **oh-my-bash** | <https://github.com/ohmybash/oh-my-bash> | The `custom/` override convention: a same-named user file shadows the shipped one. This is bebash's overlay override model ([overlay-precedence.md](overlay-precedence.md)). |
| **Bash-it** | <https://github.com/Bash-it/bash-it> | Component taxonomy (aliases/completions/plugins) and an enable/disable UX — the seed of `disabled.d/`. |
| **bash-completion** | <https://github.com/scop/bash-completion> | The canonical Bash **lazy-load-by-filename** pattern (index cheap, source on demand); per-user files under `$XDG_DATA_HOME`. Closest mature model to bebash's autoloader. |
| **ble.sh** | <https://github.com/akinomyoga/ble.sh> | Pure-Bash engineering discipline and two-phase init (load, then attach late) — the "eager spine, defer the rest" instinct. |
| **basher** | <https://github.com/basherpm/basher> | Package-as-git-repo shape: install by copy/symlink + PATH, tracked for uninstall. Reference if bebash later ships as an installable package. |
| **bpkg** | <https://github.com/bpkg/bpkg> | Package manifest metadata idea for future third-party extension packages. |
| **bashly** | <https://github.com/DannyBen/bashly> | Generated-CLI ergonomics (help/usage/completion quality) — a bar for the `bebash` management CLI. |
| **Zinit** | <https://github.com/zdharma-continuum/zinit> | Deferred/turbo loading *concept* (defer work past first prompt). Zsh-specific; the idea maps to lazy stubs, not the code. |
| **Prezto** | <https://github.com/sorin-ionescu/prezto> | Independent modules the user selects — bebash's `rc.d/` modules are the analog. |
| **fish** | <https://fishshell.com/docs/current/language.html#autoloading-functions> | Autoloading functions by filename with zero config — the UX bebash reproduces for Bash. |
| **just** | <https://just.systems/man/en/> | `just install` as the standard task surface; recipes read `PREFIX`/XDG env. |
| **release-please** | <https://github.com/googleapis/release-please> | Considered and rejected for bebash — cannot bump a marker-less `VERSION`; GitHub/Node-coupled. See [ADR-0017](../decisions/ADR-0017-git-cliff-owns-version-bump.md). |
| **git-cliff** | <https://git-cliff.org/> | Conventional-Commits changelog templating via `cliff.toml`. |

## Why not adopt a framework wholesale

oh-my-bash and bash-it are eager/plugin-list frameworks without first-call
autoloading; adopting either would trade bebash's sharp startup for their weight.
bebash instead composes the *specific* good ideas above — oh-my-bash's `custom/`
overlay + bash-completion's filename-lazy-loading + a cog-style XDG installer +
fish-style function autoload — into a leaner, more focused whole.

## Standards grounding

- XDG Base Directory: <https://specifications.freedesktop.org/basedir/latest/>
- CLI guidelines: <https://clig.dev/>
- No Color: <https://no-color.org/>
- sysexits(3): <https://man.freebsd.org/cgi/man.cgi?query=sysexits>
- Conventional Commits: <https://www.conventionalcommits.org/> · SemVer:
  <https://semver.org/> · Keep a Changelog: <https://keepachangelog.com/>
