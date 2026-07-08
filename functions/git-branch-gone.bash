# shellcheck shell=bash
: 'desc: Delete local branches whose upstream branch was deleted on the remote'

__git_branch_gone_usage() {
  cat <<'EOF'
usage: git-branch-gone [-f|--force] [-y|--yes]

Delete local branches whose upstream was deleted on the remote.
EOF
}

git-branch-gone() {
  local force=0 yes=0
  while (($#)); do
    case "$1" in
    -h | --help)
      __git_branch_gone_usage
      return 0
      ;;
    -f | --force) force=1 ;;
    -y | --yes) yes=1 ;;
    *)
      __ui_err "git-branch-gone: unknown option: $1"
      return 2
      ;;
    esac
    shift
  done
  __require_verbose git awk || return 1
  command git fetch --prune >/dev/null 2>&1 || __ui_warn "git fetch --prune failed; using cached state"
  local -a gone=()
  mapfile -t gone < <(
    command git for-each-ref --format='%(HEAD)%09%(refname:short)%09%(upstream:track)' refs/heads |
      command awk -F '\t' '$1 != "*" && $3 == "[gone]" { print $2 }'
  )
  ((${#gone[@]})) || {
    __ui_ok "no local branches with a deleted upstream"
    return 0
  }
  local -a yflag=()
  ((yes)) && yflag=(--yes)
  __ui_confirm "Delete these branch(es)?" "${yflag[@]}"
  case $? in
  0) ;;
  1)
    __ui_info "git-branch-gone: aborted"
    return 0
    ;;
  *)
    __ui_err "git-branch-gone: refusing to delete without a TTY confirmation; pass --yes"
    return 2
    ;;
  esac
  local del_flag='-d' branch
  ((force)) && del_flag='-D'
  for branch in "${gone[@]}"; do
    command git branch "$del_flag" -- "$branch" || return 1
  done
  __ui_status ok "deleted ${#gone[@]} branch(es): ${gone[*]}"
}
