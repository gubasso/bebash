# bebash — Documentation

The design, specs, and decisions for **bebash**: a self-contained, XDG-friendly
Bash framework (fish-style lazy-autoloaded functions + a split ui/log output
layer) that also ships a small `bebash` management CLI, installed with
`git clone` + `just install`.

Organized by [Diátaxis](https://diataxis.fr/) reader need. This page is only an
index into the zones — it holds no rules of its own. For an agent entry point,
load [AGENTS.md](AGENTS.md) first, then read the zone that owns the change.

## Zones

- **explanation** (Understanding):
  [Architecture](explanation/architecture.md) ·
  [Output model](explanation/output-model.md) ·
  [Overlay model](explanation/overlay-model.md) ·
  [Lazy loading](explanation/lazy-loading-model.md)
- **guides** (Task):
  [Installing](guides/installing-bebash.md) ·
  [Writing a function](guides/writing-a-function.md) ·
  [Creating an overlay](guides/creating-a-user-overlay.md) ·
  [Adding a subcommand](guides/adding-a-cli-subcommand.md) ·
  [Adding a standalone command](guides/adding-a-standalone-command.md) ·
  [Protecting branches](guides/git-branch-protection.md) ·
  [Cutting a release](guides/cutting-a-release.md)
- **reference** (Lookup): Specs index below
- **decisions** (Why): ADR index below

## Reference (specs)

- Shape: [project-layout](reference/project-layout.md) ·
  [module-and-loader](reference/module-and-loader.md) ·
  [conventions](reference/conventions.md)
- Output: [ui-api](reference/ui-api.md) ·
  [log-api](reference/log-api.md) ·
  [output-channels](reference/output-channels.md) ·
  [exit-codes](reference/exit-codes.md)
- Runtime: [config-and-xdg](reference/config-and-xdg.md) ·
  [cli-conventions](reference/cli-conventions.md) ·
  [overlay-precedence](reference/overlay-precedence.md)
- Install & release:
  [installer-and-manifest](reference/installer-and-manifest.md) ·
  [release-workflow](reference/release-workflow.md)
- Project: [privacy-tiers](reference/privacy-tiers.md) ·
  [testing](reference/testing.md) · [tooling](reference/tooling.md) ·
  [inspiration-projects](reference/inspiration-projects.md)

## Decisions

Lean ADRs (never deleted; superseded or rejected instead). Template:
[decisions/template.md](decisions/template.md).

- [ADR-0001 — Extract bebash as a standalone project](decisions/ADR-0001-extract-bebash-as-standalone-project.md)
- [ADR-0002 — Name the project `bebash`](decisions/ADR-0002-name-bebash.md)
- [ADR-0003 — Dual nature: sourced framework + management CLI](decisions/ADR-0003-dual-nature-framework-and-cli.md)
- [ADR-0004 — Install with `just` + `install.sh`](decisions/ADR-0004-install-with-just-and-install-sh.md)
- [ADR-0005 — Payload vs XDG user overlay](decisions/ADR-0005-payload-vs-xdg-user-overlay.md)
- [ADR-0006 — Idempotent `.bashrc` marker block](decisions/ADR-0006-idempotent-bashrc-marker-block.md)
- [ADR-0007 — Lazy autoload registry of kinds](decisions/ADR-0007-lazy-autoload-registry-of-kinds.md)
- [ADR-0008 — Reserve the `__log_*` namespace for machines](decisions/ADR-0008-reserve-log-namespace-for-machines.md)
- [ADR-0009 — Single palette source of truth](decisions/ADR-0009-single-palette-source-of-truth.md)
- [ADR-0010 — Eager-load output libs before helpers](decisions/ADR-0010-eager-load-output-libs-before-helpers.md)
- [ADR-0011 — Privacy strip: three tiers](decisions/ADR-0011-privacy-strip-three-tiers.md)
- [ADR-0012 — Parameterize project shortcuts](decisions/ADR-0012-parameterize-project-shortcuts.md)
- [ADR-0013 — Conventional Commits + SemVer](decisions/ADR-0013-conventional-commits-and-semver.md)
- [ADR-0014 — release-please +
  git-cliff](decisions/ADR-0014-release-please-plus-git-cliff.md)
  *(superseded by ADR-0017)*
- [ADR-0015 — `develop` integrates, `master` mirrors releases](decisions/ADR-0015-develop-integrates-master-mirrors.md)
- [ADR-0016 — The git tag is the version source of
  truth](decisions/ADR-0016-git-tag-is-version-sot.md)
  *(superseded by ADR-0018)*
- [ADR-0017 — git-cliff owns the version bump + changelog (release-please rejected)](decisions/ADR-0017-git-cliff-owns-version-bump.md)
- [ADR-0018 — The committed VERSION is the authoring source of truth; the tag mirrors it](decisions/ADR-0018-committed-version-is-authoring-sot.md)
- [ADR-0019 — Payload init shell wiring and `BEBASH_LIB` root](decisions/ADR-0019-payload-init-shell-wiring-and-bebash-lib-root.md)
- [ADR-0020 — The repository is self-contained](decisions/ADR-0020-repository-self-containment.md)
- [ADR-0035 — Native command artifacts lane](decisions/ADR-0035-native-command-artifacts-lane.md)
