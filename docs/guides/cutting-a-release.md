# Guide: Cutting a release

The day-to-day release ritual. The full spec (branch model, promotion job wiring,
`cliff.toml`) is in
[../reference/release-workflow.md](../reference/release-workflow.md); the
decisions are [ADR-0013](../decisions/ADR-0013-conventional-commits-and-semver.md),
[ADR-0015](../decisions/ADR-0015-develop-integrates-master-mirrors.md),
[ADR-0017](../decisions/ADR-0017-git-cliff-owns-version-bump.md), and
[ADR-0018](../decisions/ADR-0018-committed-version-is-authoring-sot.md).

## The short version

You write [Conventional Commits](https://www.conventionalcommits.org/) on
`develop`. When you're ready, you run `just release` — git-cliff bumps the
committed `VERSION` and `CHANGELOG.md` and you cut a signed tag — then
`git push --follow-tags`. CI publishes the Release and promotes `master`.

## 1. Land work on `develop`

Branch off `develop`, and use Conventional Commit messages so the version bump
and changelog can be derived:

```text
fix(git-branch-gone): handle detached HEAD          → patch
feat(functions): add `gi` gitignore fetcher         → minor
feat(init)!: rename BEBASH_LIB to BEBASH_HOME        → major (breaking)
docs: … / chore: … / test: …                        → no release
```

Open a PR into `develop`. CI must be green to merge.

## 2. Cut the release (on `develop`)

When the accumulated changes are worth releasing, on an up-to-date `develop`:

```bash
just release              # git-cliff --bump: writes CHANGELOG.md + VERSION,
                          # commits chore(release): vX.Y.Z, cuts a SIGNED tag
git push --follow-tags    # CI publishes the Release and promotes master
```

The committed `VERSION` is the authoring source of truth; the signed tag
is cut to mirror it. There is no Release PR or bot merge gate — the human
gate is *you*
choosing to run the ritual and push.

## 3. Verify

- `git tag` shows the new `vX.Y.Z`; the GitHub Release exists with notes.
- `VERSION` on `develop` now reads the new `X.Y.Z` (committed).
- `CHANGELOG.md` reflects the release.
- `master` now points at the tag (`git log --oneline master -1`). No human pushed
  it — CI fast-forwarded it.

## Fixing a bad release

Versions are immutable — never rewrite a published tag. Land a `fix:`
commit on `develop` and cut the next patch with `just release`.
Yank/deprecate only via a new
release, never by moving a tag.

## First release

The first release is cut the same way: `just release` from `develop`.
`git-cliff --bump` computes `v0.1.0` from the accumulated `feat:`/`fix:` commits
against the `0.0.0` baseline; there is no manifest or bot to bootstrap.
