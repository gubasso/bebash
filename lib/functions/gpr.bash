# shellcheck shell=bash
: 'desc: Check out a GitHub PR, GitLab MR, or remote branch for review'

__gpr_usage() {
  cat <<'EOF'
usage: gpr <pr-number>
      gpr --branch <name> [-f|--force]

Check out a pull request, merge request, or existing remote branch.
EOF
}

gpr() {
  local remote=origin branch='' pr='' force=0
  while (($#)); do
    case "$1" in
    -h | --help)
      __gpr_usage
      return 0
      ;;
    -f | --force) force=1 ;;
    -b | --branch)
      [[ -n "${2:-}" ]] || {
        __ui_err "gpr: --branch requires a name"
        return 2
      }
      branch=$2
      shift
      ;;
    -*)
      __ui_err "gpr: unknown option: $1"
      return 2
      ;;
    *)
      [[ -z "$pr" ]] || {
        __ui_err "gpr: unexpected argument: $1"
        return 2
      }
      pr=$1
      ;;
    esac
    shift
  done
  [[ -n "$branch$pr" ]] || {
    __gpr_usage >&2
    return 2
  }
  [[ -z "$branch" || -z "$pr" ]] || {
    __ui_err "gpr: pass either PR number or --branch"
    return 2
  }
  __require_verbose git || return 1
  if [[ -n "$branch" ]]; then
    command git fetch "$remote" || return 1
    if ((force)); then
      command git switch --track -C "$branch" "$remote/$branch"
    else
      command git switch --track -c "$branch" "$remote/$branch"
    fi
    return
  fi
  __bebash_require_lib git || return
  local forge
  forge=$(__git_forge "$remote") || forge=none
  local -a force_flag=()
  ((force)) && force_flag=(--force)
  case "$forge" in
  github)
    __require_verbose gh || return 1
    command gh pr checkout "$pr" "${force_flag[@]}"
    ;;
  gitlab)
    __require_verbose glab || return 1
    command glab mr checkout "$pr" "${force_flag[@]}"
    ;;
  *)
    __ui_err "gpr: remote has no pull-request API; pass --branch <name>"
    return 1
    ;;
  esac
}
