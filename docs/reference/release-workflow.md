# Reference: Release workflow

The mechanics of bebash releases. Decisions:
[ADR-0013](../decisions/ADR-0013-conventional-commits-and-semver.md),
[ADR-0015](../decisions/ADR-0015-develop-integrates-master-mirrors.md),
[ADR-0017](../decisions/ADR-0017-git-cliff-owns-version-bump.md),
[ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md). Day-to-day
steps: [../guides/cutting-a-release.md](../guides/cutting-a-release.md).

## Branch model

- feature branches — Where work happens; PR into `develop`.
- `develop` — Integration branch and release trigger; green CI required.
- `master` — Mirrors the latest published release; **written only by CI**.

Branch protection: only the CI identity may push `master`; humans target
`develop`.

## Version source of truth

The version has two distinct roles
([ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md)):

- The committed **`VERSION` file** (a single line, bare `X.Y.Z`) is the
  **authoring source of truth** — the one place the number is bumped, in
  place, by `git-cliff --bump`
  ([ADR-0017](../decisions/ADR-0017-git-cliff-owns-version-bump.md)).
- The signed **`vX.Y.Z` tag** is the **published record**, cut to *mirror*
  `VERSION`. Every distribution channel keys off the tag. The tag is never "the
  source of truth" — it is the immutable published marker derived from the authored
  number.

`VERSION` lives at the repo root and is committed like any other source file.
`bebash version` reads it (from the checkout or the installed payload), falling
back to `git describe --tags --dirty --always` only in a stray checkout
without a `VERSION` file.

Nothing drifts: git-cliff writes `VERSION` deterministically from the computed bump
(no marker comments, no second committed copy), and the tag is cut to match it.
There is exactly one authored place and no bot-maintained manifest to reconcile.

## Version bumps (SemVer ← Conventional Commits)

| Commit prefix                              | Bump  |
| ------------------------------------------ | ----- |
| `fix:`                                     | patch |
| `feat:`                                    | minor |
| `feat!:` / `BREAKING CHANGE:`              | major |
| `docs:` `chore:` `test:` `refactor:` `ci:` | none  |

Published versions are immutable — fix forward, never move a tag.

## Automation flow

On `develop`, the maintainer runs the release ritual (`just release`, wrapping
`git-cliff --bump` — see [ADR-0017](../decisions/ADR-0017-git-cliff-owns-version-bump.md)):

```text
on develop:
  → git-cliff computes the next version, writes CHANGELOG.md + the bare VERSION
  → commit "chore(release): vX.Y.Z" + a SIGNED annotated tag vX.Y.Z
  → git push --follow-tags
a human-pushed tag retriggers workflows, so the v* tag fires release.yml:
  → test    (reuses ci.yml)
  → release (just dist tarball + sha256, git-cliff --latest notes,
             gh release create, build-provenance attestation)
  → promote (fast-forward master onto the tag, ancestry-checked --ff-only)
```

`master` is written only by CI ([ADR-0015](../decisions/ADR-0015-develop-integrates-master-mirrors.md));
the ritual runs on `develop`.

### Promotion job wiring

A **human-pushed** `v*` tag **does** retrigger workflows, so promotion runs as a
`needs: release` job in the **same** `on: push: tags: ['v*']` run:

```bash
git fetch origin develop master --tags
git merge-base --is-ancestor "refs/tags/${TAG}" origin/develop  # reject stray tags
git checkout master
git merge --ff-only "refs/tags/${TAG}"   # ancestry-checked, never a force
git push origin master
```

The ancestry check rejects a tag not integrated on `develop`. The promote
job's own `git push origin master` uses `GITHUB_TOKEN`; it needs no
downstream retrigger since the tests already ran in this same run.

## Changelog (git-cliff)

`cliff.toml` at the repo root configures grouping (by Conventional-Commit type),
commit links, and the [Keep a Changelog](https://keepachangelog.com/) shape.
git-cliff owns **both** the version bump (`--bump`) and the changelog
formatting, so the output is fully under our control.

## Distribution

Bash has no package registry, so **the tag + GitHub Release is the release.**
`VERSION` is committed, so `git archive HEAD` already carries it — the `just dist`
recipe is a straight reproducible tarball (`git archive` pins each entry's `mtime`
to the commit and emits tree-sorted entries; `gzip -n` drops the gzip timestamp)
plus a `sha256sum` for attaching to the Release. OIDC/Trusted-Publishing is not
needed here (no registry token to mint).

Downstream packaging channels — AUR, OBS/zypper, Homebrew — are added later and
**consume the tagged tarball**; they are documented, not auto-generated pipelines.

## Sources

- Conventional Commits: <https://www.conventionalcommits.org/>
- Semantic Versioning: <https://semver.org/>
- Keep a Changelog: <https://keepachangelog.com/>
- git-cliff: <https://git-cliff.org/>
