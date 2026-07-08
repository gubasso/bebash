# shellcheck shell=bash
: 'desc: List unique emails from git history'

__git_emails_usage() {
  cat <<'EOF'
usage: git-emails [-a|-c] [-n]

List unique emails from git history.
EOF
}

git-emails() {
  local mode=both count=0
  while (($#)); do
    case "$1" in
    -h | --help)
      __git_emails_usage
      return 0
      ;;
    -a | --authors-only) mode=authors ;;
    -c | --committers-only) mode=committers ;;
    -n | --count) count=1 ;;
    *)
      __ui_err "git-emails: unknown argument: $1"
      return 2
      ;;
    esac
    shift
  done
  __require_verbose git sort uniq || return 1
  local fmt
  case "$mode" in
  authors) fmt='%ae' ;;
  committers) fmt='%ce' ;;
  *) fmt='%ae%n%ce' ;;
  esac
  if ((count)); then
    command git log --all --format="$fmt" | command sort | command uniq -c | command sort -rn
  else
    command git log --all --format="$fmt" | command sort -u
  fi
}
