# Reference: Privacy tiers

Which source functions ship in the public base and which stay in the author's
overlay. Decision:
[ADR-0011](../decisions/ADR-0011-privacy-strip-three-tiers.md), narrowed to two
tiers by [ADR-0026](../decisions/ADR-0026-retire-tier-2-parameterized-mechanism.md)
(the former "Tier 2 — parameterized" is retired; anything needing a personal target
is overlay code).

## The two tiers

| Tier | Rule                                             | Lands in                          |
| ---- | ------------------------------------------------ | --------------------------------- |
| 1    | Generic tooling, no personal data → ship as-is.  | `functions/`                  |
| 3    | Personal/company/private, or needs a personal target → never ships. | user's private overlay |

## Tier 1 — ships as-is

`git-branch-gone`, `git-email-rewrite`, `git-emails`, `gpr`, `gi`, `slug`,
`fdclip`, `ssh`, `sudo`. Pure git/util tooling; no hardcoded personal paths or
credentials.

The shipped `rc.d/` lane is also Tier 1, but intentionally narrow and
program-agnostic: it exposes bebash-managed commands on `PATH` and enables
bash-only navigation ergonomics for interactive shells.

## Tier 3 — never ships

| Function / file                | Why                                            |
| ------------------------------ | ---------------------------------------------- |
| `suse-aws-login`               | hardcoded employer AWS profile + browser profile |
| `suse-aws-env-set`             | employer AWS context tooling                   |
| `suse-docs`                    | personal `~/SUSE-docs` path                    |
| `suse-mount-gdrive`            | personal Google Drive rclone remote            |
| `claude-session-login`         | personal tool + browser profile                |
| `codex-session-login`          | personal tool + browser profile                |
| `pup`                          | Arch OS updater; overlay command using `lib/updater.bash` |
| `zup`                          | openSUSE OS updater; overlay command using `lib/updater.bash` |
| `p`                            | fuzzy-cd; needs a personal project root ([ADR-0026](../decisions/ADR-0026-retire-tier-2-parameterized-mechanism.md)) |
| `__project_nvim` + `docs`/`notes`/`todo`/`dot` | open personal dirs in `$EDITOR`; overlay `lib/` + shortcuts |
| `hosts/*.bash`                 | per-machine personal overlays                  |

These move to a private overlay, deployed the same way any user layers personal
code ([overlay model](../explanation/overlay-model.md)).

## Shipping rule

Before a function enters `functions/`, re-verify it against its source: grep
for `$HOME/<personal-dir>`, company names, credentials, browser profiles, and
personal repo paths. Anything found — including a generic mechanism that only works
once the user supplies a personal target — is Tier 3 (overlay), never Tier 1.
