# shellcheck shell=bash
: 'desc: Rewrite git history author or committer email via git filter-repo mailmap'

__git_email_rewrite_usage() {
  cat <<'EOF'
usage: git-email-rewrite [--apply] [--no-push] [--remote <name>] [-y]
                        [--keep-artifacts] [--mailmap-file <path>]
                        <old-email> <new-email> [<new-name>]

Default mode is a dry run that prints the mailmap and planned operations.
EOF
}

git-email-rewrite() {
  local apply=0 no_push=0 yes=0 keep_artifacts=0 remote=origin mailmap_file=''
  local -a positional=()
  while (($#)); do
    case "$1" in
    -h | --help)
      __git_email_rewrite_usage
      return 0
      ;;
    --apply) apply=1 ;;
    --no-push) no_push=1 ;;
    --keep-artifacts) keep_artifacts=1 ;;
    -y | --yes) yes=1 ;;
    --remote)
      [[ -n "${2:-}" ]] || {
        __ui_err "git-email-rewrite: --remote requires a value"
        return 2
      }
      remote=$2
      shift
      ;;
    --mailmap-file)
      [[ -n "${2:-}" ]] || {
        __ui_err "git-email-rewrite: --mailmap-file requires a value"
        return 2
      }
      mailmap_file=$2
      shift
      ;;
    -*)
      __ui_err "git-email-rewrite: unknown option: $1"
      return 2
      ;;
    *) positional+=("$1") ;;
    esac
    shift
  done

  __require_verbose git mktemp cat || return 1

  local old_email='' new_email='' new_name=''
  if [[ -n "$mailmap_file" ]]; then
    [[ -r "$mailmap_file" ]] || {
      __ui_err "git-email-rewrite: mailmap file not readable: $mailmap_file"
      return 1
    }
  else
    case ${#positional[@]} in
    2)
      old_email=${positional[0]}
      new_email=${positional[1]}
      new_name=${positional[1]}
      ;;
    3)
      old_email=${positional[0]}
      new_email=${positional[1]}
      new_name=${positional[2]}
      ;;
    *)
      __ui_err "git-email-rewrite: expected <old-email> <new-email> [<new-name>]"
      return 2
      ;;
    esac
  fi

  if ((apply && !yes)); then
    __ui_confirm "Rewrite git history?" || case $? in
    1) return 1 ;;
    *)
      __ui_err "git-email-rewrite: refusing non-interactive apply without --yes"
      return 2
      ;;
    esac
  fi

  # Resolve the effective mailmap into a concrete file so the same mapping that is
  # displayed here is the one handed to filter-repo during --apply. When no explicit
  # --mailmap-file is given we materialize the generated mapping into a temp file
  # rather than relying on /dev/stdin, which is not connected to this output.
  local effective_mailmap='' generated_mailmap=''
  if [[ -n "$mailmap_file" ]]; then
    effective_mailmap=$mailmap_file
    command cat -- "$mailmap_file"
  else
    generated_mailmap=$(command mktemp "${TMPDIR:-/tmp}/git-email-rewrite-mailmap.XXXXXX") || {
      __ui_err "git-email-rewrite: cannot create mailmap temp file"
      return 1
    }
    printf '%s <%s> <%s>\n' "$new_name" "$new_email" "$old_email" >"$generated_mailmap"
    effective_mailmap=$generated_mailmap
    command cat -- "$generated_mailmap"
  fi
  ((apply)) || {
    [[ -n "$generated_mailmap" ]] && command rm -f -- "$generated_mailmap"
    __ui_info "git-email-rewrite: dry run only; pass --apply to rewrite"
    return 0
  }

  # Run the destructive apply through a helper so its many early returns are funneled
  # through a single cleanup point below. This removes the generated temp mailmap
  # (which holds email identities) on every exit path without installing a RETURN trap
  # that would leak into the caller's sourced shell. A user-supplied --mailmap-file is
  # never removed.
  local rc=0
  __git_email_rewrite_apply "$effective_mailmap" "$old_email" "$remote" "$no_push" "$keep_artifacts" || rc=$?
  [[ -n "$generated_mailmap" ]] && command rm -f -- "$generated_mailmap"
  return "$rc"
}

__git_email_rewrite_apply() {
  local effective_mailmap=$1 old_email=$2 remote=$3 no_push=$4 keep_artifacts=$5

  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    __ui_err "git-email-rewrite: not inside a git work tree"
    return 1
  }

  # Mirror backup before any destructive rewrite so the pre-rewrite refs are recoverable.
  local git_dir backup_dir
  git_dir=$(command git rev-parse --git-dir 2>/dev/null) || {
    __ui_err "git-email-rewrite: cannot resolve git dir"
    return 1
  }
  backup_dir=$(command mktemp -d "${TMPDIR:-/tmp}/git-email-rewrite-backup.XXXXXX") || {
    __ui_err "git-email-rewrite: cannot create backup dir"
    return 1
  }
  if command git clone --mirror -- "$git_dir" "$backup_dir/mirror.git" >/dev/null 2>&1; then
    __ui_info "git-email-rewrite: mirror backup at $backup_dir/mirror.git"
  else
    __ui_warn "git-email-rewrite: mirror backup failed; continuing"
  fi

  command git filter-repo --force --mailmap "$effective_mailmap" || return 1

  # Post-rewrite verification: the old email must no longer appear in history.
  if [[ -n "$old_email" ]]; then
    if command git log --all --format='%ae%n%ce' | command grep -qxF -- "$old_email"; then
      __ui_err "git-email-rewrite: old email still present after rewrite; not pushing"
      __ui_hint "restore from $backup_dir/mirror.git if needed"
      return 1
    fi
    __ui_ok "git-email-rewrite: old email absent from rewritten history"
  fi

  if ((!no_push)); then
    command git push --force-with-lease "$remote" --all || {
      __ui_err "git-email-rewrite: push to $remote failed; rewritten refs not published"
      __ui_hint "mirror backup preserved at $backup_dir/mirror.git"
      return 1
    }
  fi

  if ((keep_artifacts)); then
    __ui_info "git-email-rewrite: keeping artifacts (backup: $backup_dir)"
  else
    command rm -rf -- "$backup_dir"
  fi
}
