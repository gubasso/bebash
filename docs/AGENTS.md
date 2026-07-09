---
digest-of: docs/
distilled-from:
  - https://diataxis.fr/
  - https://clig.dev/
  - https://no-color.org/
  - https://man.freebsd.org/cgi/man.cgi?query=sysexits
  - https://specifications.freedesktop.org/basedir/latest/
  - https://www.conventionalcommits.org/
  - https://semver.org/
  - https://keepachangelog.com/
  - https://github.com/googleapis/release-please
  - https://git-cliff.org/
last-synced: 2026-07-08
source-files:
  - README.md
  - explanation/architecture.md
  - explanation/output-model.md
  - explanation/overlay-model.md
  - explanation/lazy-loading-model.md
  - guides/installing-bebash.md
  - guides/writing-a-function.md
  - guides/creating-a-user-overlay.md
  - guides/adding-a-cli-subcommand.md
  - guides/adding-a-standalone-command.md
  - guides/cutting-a-release.md
  - reference/project-layout.md
  - reference/module-and-loader.md
  - reference/ui-api.md
  - reference/log-api.md
  - reference/output-channels.md
  - reference/exit-codes.md
  - reference/config-and-xdg.md
  - reference/cli-conventions.md
  - reference/installer-and-manifest.md
  - reference/overlay-precedence.md
  - reference/release-workflow.md
  - reference/privacy-tiers.md
  - reference/testing.md
  - reference/tooling.md
  - reference/conventions.md
  - reference/inspiration-projects.md
  - decisions/template.md
  - decisions/ADR-0001-extract-bebash-as-standalone-project.md
  - decisions/ADR-0002-name-bebash.md
  - decisions/ADR-0003-dual-nature-framework-and-cli.md
  - decisions/ADR-0004-install-with-just-and-install-sh.md
  - decisions/ADR-0005-payload-vs-xdg-user-overlay.md
  - decisions/ADR-0006-idempotent-bashrc-marker-block.md
  - decisions/ADR-0007-lazy-autoload-registry-of-kinds.md
  - decisions/ADR-0008-reserve-log-namespace-for-machines.md
  - decisions/ADR-0009-single-palette-source-of-truth.md
  - decisions/ADR-0010-eager-load-output-libs-before-helpers.md
  - decisions/ADR-0011-privacy-strip-three-tiers.md
  - decisions/ADR-0012-parameterize-project-shortcuts.md
  - decisions/ADR-0013-conventional-commits-and-semver.md
  - decisions/ADR-0014-release-please-plus-git-cliff.md
  - decisions/ADR-0015-develop-integrates-master-mirrors.md
  - decisions/ADR-0016-git-tag-is-version-sot.md
  - decisions/ADR-0017-git-cliff-owns-version-bump.md
  - decisions/ADR-0018-committed-version-is-authoring-sot.md
  - decisions/ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md
  - decisions/ADR-0020-repository-self-containment.md
  - decisions/ADR-0021-payload-fhs-role-split.md
  - decisions/ADR-0022-overlay-config-vs-data-split.md
  - decisions/ADR-0023-standalone-command-lane-and-naming.md
token-estimate: 24000
---

# Agent digest — bebash docs

This digest **maps** the docs shelf; it does not restate it. When this file and
a zone file disagree, **the zone file wins** — regenerate this digest, never
promote it to source of truth. For agent *working conventions* (self-containment,
ADR discipline, lint/test, commit and branch rules), the repo-root
[`AGENTS.md`](../AGENTS.md) is the source of truth; this digest owns docs navigation.

## Scope

bebash is a public, XDG-friendly Bash **framework** (lazy-autoloaded functions +
`rc.d` modules + a split `__ui_*`/`__log_*` output layer) that **also** ships a
small `bebash` management CLI. Installed by cloning the repo and running
`just install`; users layer their own functions/config on top via an overlay
directory. These docs are the design + spec that drive the implementation.

## Key points by zone

- **explanation/** — the mental models. Dual nature (framework first, CLI
  second) and the `init.bash` load pipeline; the three output audiences
  (`__ui_*` humans / `__log_*` machines / plain stdout results); the
  payload-vs-overlay precedence; the autoload registry and what stays eager.
- **guides/** — task sequences: install, write a function, build a user overlay,
  add a CLI subcommand, cut a release.
- **reference/** — the specs (exact tables, signatures, step sequences): project
  layout, module/loader, `ui`/`log` APIs, output channels, exit codes, config +
  XDG, CLI conventions, installer + manifest, overlay precedence, release
  workflow, privacy tiers, testing, tooling, conventions, inspiration projects.
- **decisions/** — 23 lean ADRs (`ADR-NNNN-slug.md`, ≤350 words, never deleted).

## Source map

| Topic                       | Owner file                              |
| --------------------------- | --------------------------------------- |
| Load pipeline / dual nature | explanation/architecture.md             |
| ui vs log vs stdout         | explanation/output-model.md             |
| Payload vs user overlay     | explanation/overlay-model.md            |
| Lazy autoload / eager core  | explanation/lazy-loading-model.md       |
| `__ui_*` API + palette      | reference/ui-api.md                     |
| `__log_*` API + logfmt      | reference/log-api.md                    |
| Exit codes / err.kind       | reference/exit-codes.md                 |
| XDG paths + config layers   | reference/config-and-xdg.md             |
| Installer + manifest        | reference/installer-and-manifest.md     |
| Release flow                | reference/release-workflow.md           |
| Which functions ship        | reference/privacy-tiers.md              |

## Maintenance

Regenerate from `source-files` when zones change. Keep `last-synced` current.
Provenance is to public upstreams only — this shelf is self-contained.
