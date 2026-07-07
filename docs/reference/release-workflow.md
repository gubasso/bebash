# Reference: Release workflow

The mechanics of bebash releases. Decisions:
[ADR-0013](../decisions/ADR-0013-conventional-commits-and-semver.md),
[ADR-0014](../decisions/ADR-0014-release-please-plus-git-cliff.md),
[ADR-0015](../decisions/ADR-0015-develop-integrates-master-mirrors.md). Day-to-day
steps: [../guides/cutting-a-release.md](../guides/cutting-a-release.md).

## Branch model

| Branch            | Role                                                             |
| ----------------- | --------------------------------------------------------------- |
| feature branches  | Where work happens; PR into `develop`.                          |
| `develop`         | Integration branch and release trigger; green CI required.      |
| `master`          | Mirrors the latest published release; **written only by CI**.   |

Branch protection: only the CI identity may push `master`; humans target
`develop`.

## Version source of truth

- `VERSION` at the repo root holds the current `X.Y.Z`.
- release-please's manifest (`.release-please-manifest.json`) tracks the same
  number for the `simple` release type; the two stay in sync.
- `bebash version` reads `VERSION`, falling back to `git describe --tags --dirty
  --always` in a dev checkout.

## Version bumps (SemVer ← Conventional Commits)

| Commit prefix                    | Bump  |
| -------------------------------- | ----- |
| `fix:`                           | patch |
| `feat:`                          | minor |
| `feat!:` / `BREAKING CHANGE:`    | major |
| `docs:` `chore:` `test:` `refactor:` `ci:` | none |

Published versions are immutable — fix forward, never move a tag.

## Automation flow

```text
push to develop
  → release-please opens/updates a Release PR
      (bumps VERSION + manifest, regenerates CHANGELOG.md via git-cliff)
  → maintainer reviews and MERGES the Release PR   ← the human gate
  → release-please tags vX.Y.Z + creates the GitHub Release
  → promotion job fast-forwards master to the tag  (git merge --ff-only)
```

### Promotion job wiring

A bot-created tag pushed with `GITHUB_TOKEN` does **not** retrigger workflows, so
promotion runs as a `needs:` job in the **same** release run, reading the tag name
from release-please's output, and does:

```bash
git fetch origin
git checkout master
git merge --ff-only "refs/tags/${TAG}"   # ancestry-checked
git push origin master
```

If releases were ever cut by a human-pushed tag instead, promotion would move to a
separate `on: push: tags: ['v*']` workflow (a tag push *does* retrigger).

## Changelog (git-cliff)

`cliff.toml` at the repo root configures grouping (by Conventional-Commit type),
commit links, and the [Keep a Changelog](https://keepachangelog.com/) shape.
release-please invokes the changelog step; git-cliff owns the formatting so the
output is fully under our control.

## Distribution

Bash has no package registry, so **the tag + GitHub Release is the release.** The
`just dist` recipe produces a reproducible tarball (`git archive`) plus a
`sha256sum` for attaching to the Release. OIDC/Trusted-Publishing is not needed
here (no registry token to mint); if a downstream package (AUR, OBS, Homebrew) is
added later, it consumes the tagged tarball.

## Sources

- Conventional Commits: <https://www.conventionalcommits.org/>
- Semantic Versioning: <https://semver.org/>
- Keep a Changelog: <https://keepachangelog.com/>
- release-please: <https://github.com/googleapis/release-please>
- git-cliff: <https://git-cliff.org/>
