# shellcheck shell=bash
: 'desc: unified GitHub and GitLab branch-protection: apply, verify, or look up rulesets'

__git_branch_protection_usage() {
  cat <<'EOF'
Usage:
  git-branch-protection [global flags] gh   <owner/repo>    [apply] [--required-checks a,b] [--bypass-actor-id ID] [--default-branch develop]
  git-branch-protection [global flags] gh   <owner/repo>    verify
  git-branch-protection [global flags] gh   <owner/repo>    lookup
  git-branch-protection [global flags] glab <group/project> [apply] [--tier free|premium] [--bot-user-id ID] [--merge-method ff] [--tag-pattern v*] [--default-branch develop]
  git-branch-protection [global flags] glab <group/project> verify

Global flags:
  --json                  Emit a structured summary on stdout.
  -v, -vv                 Increase terminal detail.
  -q, --quiet, --silent   Reduce terminal UI.
  --color MODE            auto, always, or never.
  -y, --yes               Accept prompts where supported.
  --non-interactive       Never prompt.
  -h, --help              Show this help.

GitHub options:
  --required-checks LIST  Comma-separated status check contexts to require.
  --bypass-actor-id ID    Installed GitHub App actor id for default branch/tag bypass.
  --default-branch NAME   Branch to set as the repository default.

GitLab options:
  --tier free|premium     Select free or premium branch-protection behavior.
  --bot-user-id ID        GitLab bot user id for Premium protected branches.
  --merge-method METHOD   ff, rebase_merge, or merge.
  --tag-pattern GLOB      Protected release tag glob.
  --default-branch NAME   Branch to set as the project default.

Verbs:
  apply                   Apply rulesets/protection. This is the default verb.
  verify                  Print host-side protection state.
  lookup                  Look up the GitHub App bypass actor id. Unsupported for GitLab.
EOF
}

git-branch-protection() {
  [[ "${1:-}" == -h || "${1:-}" == --help ]] && {
    __git_branch_protection_usage
    return 0
  }
  __bebash_require_lib git_branch_protection || return 1
  __git_branch_protection_main "$@"
}
