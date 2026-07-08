# Reference: Config and XDG paths

Where bebash reads and writes, the config precedence order, and the environment
variables it honors.

## XDG base directories

bebash is XDG-first; it never uses `~/.bebash/`. Defaults follow the
[XDG Base Directory spec](https://specifications.freedesktop.org/basedir/latest/):

| Purpose            | Variable          | bebash path (default)                       |
| ------------------ | ----------------- | ------------------------------------------- |
| User config        | `XDG_CONFIG_HOME` | `~/.config/bebash/`                         |
| User code/data     | `XDG_DATA_HOME`   | `~/.local/share/bebash/`                    |
| Shipped payload    | `PREFIX`          | `~/.local/lib/bebash/` (`$PREFIX/lib/bebash`) |
| CLI on PATH        | `PREFIX`          | `~/.local/bin/bebash`                       |
| State (logs, manifest) | `XDG_STATE_HOME` | `~/.local/state/bebash/`                 |
| Cache (autoload index) | `XDG_CACHE_HOME` | `~/.cache/bebash/`                       |
| Data (completion)  | `XDG_DATA_HOME`   | `~/.local/share/bash-completion/completions/` |

Runtime resolution: `init.bash` sets `BEBASH_LIB` (payload root),
`BEBASH_CONFIG_DIR` (config root), and `BEBASH_DATA_DIR` (user code/data root).
Layout details:
[overlay-precedence.md](overlay-precedence.md),
[installer-and-manifest.md](installer-and-manifest.md).

## Config precedence

Effective settings merge from lowest to highest precedence:

```text
built-in defaults  <  user config.bash  <  environment vars  <  CLI flags
```

- **Defaults** — hard-coded in the shipped code; always present.
- **`config.bash`** — `~/.config/bebash/config.bash`, sourced
  last in the load pipeline so it can override shipped defaults.
- **Environment** — `BEBASH_*` vars for a session/invocation.
- **CLI flags** — highest; a one-off override for a single `bebash` call.

## Environment variables

| Variable               | Effect                                                     |
| ---------------------- | ---------------------------------------------------------- |
| `BEBASH_LIB`           | Payload root (set by `init.bash`; override for testing).   |
| `BEBASH_CONFIG_DIR`    | Config root (default `$XDG_CONFIG_HOME/bebash`).             |
| `BEBASH_DATA_DIR`      | User code/data root (default `$XDG_DATA_HOME/bebash`).       |
| `BEBASH_PROJECT_ROOTS` | Array of roots for the `p` fuzzy-cd function (default `("$HOME/Projects")`). |
| `BEBASH_LOG_LEVEL`     | Machine-log threshold (default `warn`). See [log-api.md](log-api.md). |
| `BEBASH_LOG_STDERR`    | Mirror log records to stderr when non-empty.               |
| `BEBASH_LOG_FILE`      | Override the log file path.                                 |
| `NO_COLOR` / `FORCE_COLOR` | Color gating (see [ui-api.md](ui-api.md)).             |

Naming: app vars are prefixed `BEBASH_`. Path overrides honor the standard XDG
vars too. bebash does not invent a `BEBASH_LOG` alias for the level — the level
var is `BEBASH_LOG_LEVEL`.

## Project shortcuts (Tier-2 config)

Functions that used to hardcode the author's directories now read config
([ADR-0012](../decisions/ADR-0012-parameterize-project-shortcuts.md)):

```bash
# ~/.config/bebash/config.bash
BEBASH_PROJECT_ROOTS=("$HOME/Projects" "$HOME/Sources")   # for `p`
docs() { __project_nvim docs "$HOME/Documents" "$@"; }     # your own shortcut
```

The `__project_nvim` mechanism ships; the concrete targets are yours. See
[privacy-tiers.md](privacy-tiers.md) for which functions are parameterized.

## Sources

- XDG Base Directory: <https://specifications.freedesktop.org/basedir/latest/>
