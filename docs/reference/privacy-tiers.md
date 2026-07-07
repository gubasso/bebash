# Reference: Privacy tiers

Which source functions ship in the public base, which ship parameterized, and
which stay in the author's overlay. Decision:
[ADR-0011](../decisions/ADR-0011-privacy-strip-three-tiers.md); parameterization:
[ADR-0012](../decisions/ADR-0012-parameterize-project-shortcuts.md).

## The three tiers

| Tier | Rule                                             | Lands in                          |
| ---- | ------------------------------------------------ | --------------------------------- |
| 1    | Generic tooling, no personal data → ship as-is.  | `lib/functions/`                  |
| 2    | Generic behavior, hardcodes author's layout → ship the mechanism, drive targets from config. | `lib/functions/` + `config.bash` defaults |
| 3    | Personal/company/private → never ships.          | author's `~/.dotfiles/bebash/` overlay |

## Tier 1 — ships as-is

`git-branch-gone`, `git-email-rewrite`, `git-emails`, `gpr`, `gi`, `slug`,
`fdclip`, `ssh`, `sudo`. Pure git/util tooling; no hardcoded personal paths or
credentials.

## Tier 2 — ships, parameterized

| Function        | Hardcoded today            | Parameterization                            |
| --------------- | -------------------------- | ------------------------------------------- |
| `p`             | `~/Sources`, `~/Projects`  | reads `BEBASH_PROJECT_ROOTS` (defaults provided) |
| `pup`           | a personal `dwm` clone path | optional `BEBASH_DWM_PATH` (default: off)  |
| `docs`/`notes`/`todo`/`dot` | fixed dirs via `__project_nvim` | ship `__project_nvim`; declare shortcuts in `config.bash` |

The `__project_nvim` helper is the reusable mechanism; the concrete targets are
user config, so only the pattern ships publicly.

## Tier 3 — never ships

| Function / file                | Why                                            |
| ------------------------------ | ---------------------------------------------- |
| `suse-aws-login`               | hardcoded employer AWS profile + browser profile |
| `suse-aws-env-set`             | employer AWS context tooling                   |
| `suse-docs`                    | personal `~/SUSE-docs` path                    |
| `suse-mount-gdrive`            | personal Google Drive rclone remote            |
| `claude-session-login`         | personal tool + browser profile                |
| `codex-session-login`          | personal tool + browser profile                |
| `hosts/*.bash`                 | per-machine personal overlays                  |

These move to the author's `~/.dotfiles/bebash/` overlay, deployed the same way
any user layers personal code ([overlay model](../explanation/overlay-model.md)).

## Shipping rule

Before a function enters `lib/functions/`, re-verify it against its source: grep
for `$HOME/<personal-dir>`, company names, credentials, browser profiles, and
personal repo paths. Anything found → Tier 2 (parameterize) or Tier 3 (overlay),
never Tier 1.
