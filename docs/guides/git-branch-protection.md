# Guide: Protecting branches with git-branch-protection

Use `git-branch-protection` to apply and inspect branch-protection rules for repositories that use a
protected default branch, an integration branch, and immutable release tags. The command keeps project
data out of the shipped files: repo names, check names, bypass actor ids, and bot ids are supplied at
runtime.

Ruleset artifact precedence is specified in
[overlay-precedence](../reference/overlay-precedence.md), and command shape follows
[conventions](../reference/conventions.md). Artifact decisions are recorded in
[ADR-0034](../decisions/ADR-0034-command-private-artifacts-lane.md) and
[ADR-0035](../decisions/ADR-0035-native-command-artifacts-lane.md).

## What the command does

`git-branch-protection` accepts `gh` or `glab`, a target, and an optional verb:

```bash
git-branch-protection <gh|glab> <target> [apply|verify|lookup] [options]
```

For GitHub, it posts the shipped `master`, `develop`, and `tags` rulesets, can inject required status
checks, resolves the installed App bypass actor at runtime, sets the default branch, and verifies the
result. For GitLab, it configures protected branches, protected tags, merge hygiene, and the default
branch through `glab`.

## Prerequisites

- `gh` authenticated for GitHub targets or `glab` authenticated for GitLab targets.
- `jq` available locally.
- Admin or maintainer rights for the target repository/project.
- Actual CI check names, such as `<check-name>`.
- For GitHub, an installed GitHub App on the repository when using the default bypass flow.
- For GitLab Premium, a bot user id if automatic matching is not enough.

## Apply GitHub rulesets

```bash
git-branch-protection gh <owner/repo> apply --required-checks <check-name>
```

`apply` is the default verb, so this is equivalent:

```bash
git-branch-protection gh <owner/repo> --required-checks <check-name>
```

The bypass actor chain is fail-closed: `--bypass-actor-id <app-id>` wins; otherwise the command runs
`gh api "/repos/<owner/repo>/installation" --jq '.app_id'`; otherwise it fails and asks you to supply
the id. The App id is never stored in the ruleset JSON.

To set a different default branch after applying rulesets:

```bash
git-branch-protection gh <owner/repo> apply --default-branch develop --required-checks <check-name>
```

## Verify and look up

```bash
git-branch-protection gh <owner/repo> verify
git-branch-protection gh <owner/repo> lookup
```

`verify` prints the host-side ruleset state and checks whether `master` and `develop` match a ruleset.
`lookup` prints the installed GitHub App id for use with `--bypass-actor-id <app-id>`.

## JSON output

Put global flags before the provider:

```bash
git-branch-protection --json gh <owner/repo> apply --required-checks <check-name>
```

JSON mode writes a structured summary to stdout and captures host command output in an `events` array.

## Required checks

Pass a comma-separated list when the host should require more than one context:

```bash
git-branch-protection gh <owner/repo> apply --required-checks <check-name>,<check-name>
```

Use the exact context names emitted by the target project's CI.

## Customize rulesets

The native rulesets live under `$BEBASH_LIB/artifacts/git-branch-protection/rulesets/`. To override
them, copy all three files into:

```text
$BEBASH_DATA_DIR/artifacts/git-branch-protection/rulesets/{master,develop,tags}.json
```

The overlay directory overrides the native directory as a whole subtree. If an overlay rulesets
directory exists but is missing one of the three files, the command fails instead of filling gaps from
the native payload.

## GitLab notes

```bash
git-branch-protection glab <group/project> apply --tier free --default-branch develop
git-branch-protection glab <group/project> apply --tier premium --bot-user-id <bot-user-id>
git-branch-protection glab <group/project> verify
```

GitLab `lookup` is unsupported; pass `--bot-user-id` for Premium projects when needed. `--merge-method`
sets the project merge method, and `--tag-pattern` changes the protected release tag glob.
