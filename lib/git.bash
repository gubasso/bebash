# shellcheck shell=bash
: 'desc: shared git helpers'

[[ -n "${__bebash_git_loaded:-}" ]] && return 0
__bebash_git_loaded=1

__git_forge() {
  local remote=${1:-origin} url host
  url=$(command git remote get-url "$remote" 2>/dev/null) || return 1
  host=${url#*://}
  host=${host#*@}
  host=${host%%[:/]*}

  case "$host" in
  github.com | *.github.com) printf 'github\n' ;;
  gitlab.com | gitlab.* | *.gitlab.*) printf 'gitlab\n' ;;
  *) printf 'none\n' ;;
  esac
}
