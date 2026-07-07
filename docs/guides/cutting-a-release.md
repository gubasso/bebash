# Guide: Cutting a release

The day-to-day release ritual. The full spec (branch model, promotion job wiring,
`cliff.toml`) is in
[../reference/release-workflow.md](../reference/release-workflow.md); the
decisions are [ADR-0013](../decisions/ADR-0013-conventional-commits-and-semver.md),
[ADR-0014](../decisions/ADR-0014-release-please-plus-git-cliff.md), and
[ADR-0015](../decisions/ADR-0015-develop-integrates-master-mirrors.md).

## The short version

You don't cut a release by hand. You write [Conventional
Commits](https://www.conventionalcommits.org/); a bot proposes the release; you
merge it.

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

## 2. Let the Release PR accumulate

On each push to `develop`, **release-please** opens or updates a **Release PR**
that bumps the version (in `VERSION` + the release-please manifest) and rewrites
`CHANGELOG.md` from the commits since the last release (via git-cliff). You don't
edit this PR — you review it.

## 3. Merge the Release PR (the human gate)

When the accumulated changes are worth releasing, merge the Release PR. Merging
is the gate: nothing publishes without it. On merge, the automation:

1. tags the release (`vX.Y.Z`);
2. creates the GitHub Release with the changelog notes;
3. runs the promotion job, which **fast-forwards `master` to the tag**
   (`git merge --ff-only`, ancestry-checked). No human pushes to `master`.

## 4. Verify

- `git tag` shows the new `vX.Y.Z`; the GitHub Release exists with notes.
- `master` now points at the tag (`git log --oneline master -1`).
- `VERSION` and `CHANGELOG.md` on `develop` reflect the release.

## Fixing a bad release

Versions are immutable — never rewrite a published tag. Land a `fix:` commit on
`develop` and let the next Release PR ship a new patch. Yank/deprecate only via a
new release, never by moving a tag.

## First release / manual fallback

The very first tag may need to be created by hand to bootstrap the manifest;
after that the bot takes over. A fully manual path (bump `VERSION`, run git-cliff,
`gh release create`) is described as the fallback in
[../reference/release-workflow.md](../reference/release-workflow.md).
