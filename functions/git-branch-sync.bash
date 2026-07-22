# shellcheck shell=bash
: 'desc: Sync local branches with a remote: 3-way diff, pick actions, confirm, apply'

__git_branch_sync_usage() {
  cat <<'EOF'
usage: git-branch-sync [-r|--remote <name>] [-n|--dry-run] [-y|--yes] [-f|--force]
      git-branch-sync --gone [-y|--yes] [-f|--force]

Reconcile local branches with one remote. Shows a 3-way diff (in both /
only local / only remote), lets you pick branches and actions, prints the
planned git commands, and applies them after confirmation.

options:
  -r, --remote <name>  remote to sync with (default: origin)
      --gone           only delete local branches whose upstream is gone
  -n, --dry-run        print the report and the default constructive plan
  -y, --yes            skip the final confirmation
  -f, --force          use 'git branch -D' for local deletions
  -h, --help           show this help
EOF
}

# Populates the caller's __gbs_* arrays (bash dynamic scoping) from one
# snapshot of refs/heads and refs/remotes/<remote>/.
__git_branch_sync_scan() {
  local remote=$1
  local -A tracked=() local_names=()
  local head name upstream uremote track a b
  # Tab is IFS whitespace, so empty fields collapse; safe here because
  # %(HEAD) is never empty ('*' or ' ') and empty fields only occur trailing.
  while IFS=$'\t' read -r head name upstream uremote track; do
    [[ -n "$name" ]] || continue
    local_names["$name"]=1
    [[ "$head" == '*' ]] && __gbs_current=$name
    if [[ -z "$upstream" ]]; then
      __gbs_local_new+=("$name")
    elif [[ "$uremote" != "$remote" ]]; then
      __gbs_other_remote+=("$name"$'\t'"$upstream")
    elif [[ "$track" == '[gone]' ]]; then
      __gbs_local_gone+=("$name")
    else
      tracked["$upstream"]=1
      a=0 b=0
      [[ "$track" =~ ahead\ ([0-9]+) ]] && a=${BASH_REMATCH[1]}
      [[ "$track" =~ behind\ ([0-9]+) ]] && b=${BASH_REMATCH[1]}
      if ((a > 0 && b > 0)); then
        __gbs_diverged+=("$name"$'\t'"$a"$'\t'"$b")
      elif ((a > 0)); then
        __gbs_ahead+=("$name"$'\t'"$a")
      elif ((b > 0)); then
        __gbs_behind+=("$name"$'\t'"$b")
      else
        __gbs_insync+=("$name")
      fi
    fi
  done < <(
    command git for-each-ref \
      --format='%(HEAD)%09%(refname:short)%09%(upstream:short)%09%(upstream:remotename)%09%(upstream:track)' \
      refs/heads
  )

  local ref symref rname
  while IFS=$'\t' read -r ref symref; do
    [[ -n "$ref" && -z "$symref" ]] || continue
    rname=${ref#refs/remotes/"$remote"/}
    [[ "$rname" == HEAD ]] && continue
    [[ -n "${tracked["$remote/$rname"]:-}" ]] && continue
    if [[ -n "${local_names["$rname"]:-}" ]]; then
      __gbs_remote_unlinked+=("$rname")
    else
      __gbs_remote_only+=("$rname")
    fi
  done < <(
    command git for-each-ref --format='%(refname)%09%(symref)' "refs/remotes/$remote/"
  )
}

__git_branch_sync_report() {
  local remote=$1
  local w=0 name entry a b
  for entry in "${__gbs_insync[@]}" "${__gbs_ahead[@]}" "${__gbs_behind[@]}" \
    "${__gbs_diverged[@]}" "${__gbs_local_new[@]}" "${__gbs_local_gone[@]}" \
    "${__gbs_remote_only[@]}"; do
    name=${entry%%$'\t'*}
    ((${#name} > w)) && w=${#name}
  done

  local n_both=$((${#__gbs_insync[@]} + ${#__gbs_ahead[@]} + ${#__gbs_behind[@]} + ${#__gbs_diverged[@]}))
  if ((n_both)); then
    __ui_head "== both ($n_both) =="
    for name in "${__gbs_insync[@]}"; do
      __ui_field "$w" "$name" "✓ in sync"
    done
    for entry in "${__gbs_ahead[@]}"; do
      IFS=$'\t' read -r name a <<<"$entry"
      __ui_field "$w" "$name" "↑$a ahead"
    done
    for entry in "${__gbs_behind[@]}"; do
      IFS=$'\t' read -r name b <<<"$entry"
      __ui_field "$w" "$name" "↓$b behind"
    done
    for entry in "${__gbs_diverged[@]}"; do
      IFS=$'\t' read -r name a b <<<"$entry"
      __ui_field "$w" "$name" "↑$a ↓$b diverged (no action offered; resolve manually)"
    done
  fi

  local n_local=$((${#__gbs_local_new[@]} + ${#__gbs_local_gone[@]}))
  if ((n_local)); then
    __ui_head "== only local ($n_local) =="
    for name in "${__gbs_local_new[@]}"; do
      __ui_field "$w" "$name" "(no upstream)"
    done
    for name in "${__gbs_local_gone[@]}"; do
      __ui_field "$w" "$name" "[gone]"
    done
  fi

  if ((${#__gbs_remote_only[@]})); then
    __ui_head "== only remote (${#__gbs_remote_only[@]}) =="
    for name in "${__gbs_remote_only[@]}"; do
      __ui_field "$w" "$name" ""
    done
  fi

  for entry in "${__gbs_other_remote[@]}"; do
    IFS=$'\t' read -r name a <<<"$entry"
    __ui_hint "$name tracks $a — ignored (syncing with $remote)"
  done
  for name in "${__gbs_remote_unlinked[@]}"; do
    __ui_hint "$name exists on $remote and locally without tracking — link: git branch -u $remote/$name $name"
  done
}

# __git_branch_sync_pick <outvar> <title> <items...>
# Fills <outvar> with the selection (empty on cancel); returns 2 when no
# picker is available at all.
__git_branch_sync_pick() {
  local -n __gbs_sel="$1"
  local title=$2
  shift 2
  __gbs_sel=()
  (($#)) || return 0
  local out rc=0
  out=$(interact::pick_multi "$title" "$@") || rc=$?
  case $rc in
  0) [[ -n "$out" ]] && mapfile -t __gbs_sel <<<"$out" ;;
  1) ;;
  *) return 2 ;;
  esac
  return 0
}

__git_branch_sync_gone() {
  local remote=$1 yes=$2 force=$3 dry=$4
  local -a gone=()
  local name
  for name in "${__gbs_local_gone[@]}"; do
    if [[ "$name" == "$__gbs_current" ]]; then
      __ui_warn "current branch $name has a gone upstream; switch away to delete it"
    else
      gone+=("$name")
    fi
  done
  ((${#gone[@]})) || {
    __ui_ok "no local branches with a deleted upstream"
    return 0
  }
  local del_flag='-d'
  ((force)) && del_flag='-D'
  for name in "${gone[@]}"; do
    printf 'git branch %s -- %s\n' "$del_flag" "$name"
  done
  ((dry)) && return 0
  local -a yflag=()
  ((yes)) && yflag=(--yes)
  __ui_confirm "Delete these branch(es)?" "${yflag[@]}"
  case $? in
  0) ;;
  1)
    __ui_info "git-branch-sync: aborted"
    return 0
    ;;
  *)
    __ui_err "git-branch-sync: refusing to delete without a TTY confirmation; pass --yes"
    return 2
    ;;
  esac
  for name in "${gone[@]}"; do
    command git branch "$del_flag" -- "$name" || return 1
  done
  __log_info "git-branch-sync: deleted gone branches" "count=${#gone[@]}"
  __ui_status ok "deleted ${#gone[@]} branch(es): ${gone[*]}"
}

git-branch-sync() {
  local remote=origin gone_only=0 dry=0 yes=0 force=0
  while (($#)); do
    case "$1" in
    -h | --help)
      __git_branch_sync_usage
      return 0
      ;;
    -r | --remote)
      [[ -n "${2:-}" ]] || {
        __ui_err "git-branch-sync: --remote requires a name"
        return 2
      }
      remote=$2
      shift
      ;;
    --gone) gone_only=1 ;;
    -n | --dry-run) dry=1 ;;
    -y | --yes) yes=1 ;;
    -f | --force) force=1 ;;
    *)
      __ui_err "git-branch-sync: unknown option: $1"
      return 2
      ;;
    esac
    shift
  done
  __require_verbose git || return 1
  command git rev-parse --git-dir >/dev/null 2>&1 || {
    __ui_err "git-branch-sync: not inside a git repository"
    return 2
  }
  command git remote get-url -- "$remote" >/dev/null 2>&1 || {
    __ui_err "git-branch-sync: no such remote: $remote"
    return 2
  }
  command git fetch --prune -- "$remote" >/dev/null 2>&1 ||
    __ui_warn "git fetch --prune failed; using cached state"

  local __gbs_current=''
  local -a __gbs_insync=() __gbs_ahead=() __gbs_behind=() __gbs_diverged=()
  local -a __gbs_local_new=() __gbs_local_gone=() __gbs_remote_only=()
  local -a __gbs_other_remote=() __gbs_remote_unlinked=()
  __git_branch_sync_scan "$remote"

  if ((gone_only)); then
    __git_branch_sync_gone "$remote" "$yes" "$force" "$dry"
    return
  fi

  __git_branch_sync_report "$remote"

  if ((${#__gbs_ahead[@]} + ${#__gbs_behind[@]} + ${#__gbs_local_new[@]} + \
    ${#__gbs_local_gone[@]} + ${#__gbs_remote_only[@]} == 0)); then
    __ui_ok "all ${#__gbs_insync[@]} branch(es) in sync with $remote"
    return 0
  fi

  local del_flag='-d'
  ((force)) && del_flag='-D'
  # Plan entries are tab-separated git argv (ref names cannot contain
  # whitespace); staged additive -> destructive.
  local -a plan_create=() plan_push=() plan_ff=() plan_dellocal=() plan_delremote=()
  local entry name n line

  if ((dry)); then
    # Deterministic plan: the default constructive action per branch;
    # destructive actions are only reachable interactively or via --gone.
    for entry in "${__gbs_ahead[@]}"; do
      plan_push+=("push"$'\t'"--"$'\t'"$remote"$'\t'"${entry%%$'\t'*}")
    done
    for entry in "${__gbs_behind[@]}"; do
      name=${entry%%$'\t'*}
      if [[ "$name" == "$__gbs_current" ]]; then
        plan_ff+=("merge"$'\t'"--ff-only"$'\t'"@{u}")
      else
        plan_ff+=("fetch"$'\t'"--"$'\t'"$remote"$'\t'"$name:$name")
      fi
    done
    for name in "${__gbs_local_new[@]}"; do
      plan_push+=("push"$'\t'"-u"$'\t'"--"$'\t'"$remote"$'\t'"$name")
    done
    for name in "${__gbs_remote_only[@]}"; do
      plan_create+=("branch"$'\t'"--track"$'\t'"--"$'\t'"$name"$'\t'"$remote/$name")
    done
    for name in "${__gbs_local_gone[@]}"; do
      __ui_hint "$name [gone] — delete with --gone, or pick an action interactively"
    done
  else
    __bebash_require_lib interact || return
    local -a items=() sel=()
    local -A chosen=()

    for entry in "${__gbs_ahead[@]}"; do
      IFS=$'\t' read -r name n <<<"$entry"
      items+=("$name ↑$n push")
    done
    for entry in "${__gbs_behind[@]}"; do
      IFS=$'\t' read -r name n <<<"$entry"
      items+=("$name ↓$n fast-forward")
    done
    __git_branch_sync_pick sel "Sync with $remote" "${items[@]}" || {
      __ui_err "git-branch-sync: no interactive picker available; use --dry-run or --gone"
      return 2
    }
    for line in "${sel[@]}"; do
      name=${line%% *}
      if [[ "$line" == *push ]]; then
        plan_push+=("push"$'\t'"--"$'\t'"$remote"$'\t'"$name")
      elif [[ "$name" == "$__gbs_current" ]]; then
        plan_ff+=("merge"$'\t'"--ff-only"$'\t'"@{u}")
      else
        plan_ff+=("fetch"$'\t'"--"$'\t'"$remote"$'\t'"$name:$name")
      fi
    done

    items=()
    for name in "${__gbs_local_new[@]}"; do
      items+=("$name (no upstream)")
    done
    for name in "${__gbs_local_gone[@]}"; do
      items+=("$name [gone] re-push")
    done
    __git_branch_sync_pick sel "Publish to $remote (push -u)" "${items[@]}" || {
      __ui_err "git-branch-sync: no interactive picker available; use --dry-run or --gone"
      return 2
    }
    for line in "${sel[@]}"; do
      name=${line%% *}
      chosen["$name"]=1
      plan_push+=("push"$'\t'"-u"$'\t'"--"$'\t'"$remote"$'\t'"$name")
    done

    items=()
    for name in "${__gbs_local_new[@]}" "${__gbs_local_gone[@]}"; do
      [[ -n "${chosen["$name"]:-}" || "$name" == "$__gbs_current" ]] && continue
      items+=("$name")
    done
    __git_branch_sync_pick sel "Delete LOCAL branches (git branch $del_flag)" "${items[@]}" || {
      __ui_err "git-branch-sync: no interactive picker available; use --dry-run or --gone"
      return 2
    }
    for line in "${sel[@]}"; do
      plan_dellocal+=("branch"$'\t'"$del_flag"$'\t'"--"$'\t'"${line%% *}")
    done

    __git_branch_sync_pick sel "Create local tracking branches" "${__gbs_remote_only[@]}" || {
      __ui_err "git-branch-sync: no interactive picker available; use --dry-run or --gone"
      return 2
    }
    for line in "${sel[@]}"; do
      name=${line%% *}
      chosen["remote:$name"]=1
      plan_create+=("branch"$'\t'"--track"$'\t'"--"$'\t'"$name"$'\t'"$remote/$name")
    done

    items=()
    for name in "${__gbs_remote_only[@]}"; do
      [[ -n "${chosen["remote:$name"]:-}" ]] && continue
      items+=("$name")
    done
    __git_branch_sync_pick sel "Delete REMOTE branches on $remote" "${items[@]}" || {
      __ui_err "git-branch-sync: no interactive picker available; use --dry-run or --gone"
      return 2
    }
    for line in "${sel[@]}"; do
      plan_delremote+=("push"$'\t'"--delete"$'\t'"--"$'\t'"$remote"$'\t'"${line%% *}")
    done
  fi

  local -a plan=(
    "${plan_create[@]}" "${plan_push[@]}" "${plan_ff[@]}"
    "${plan_dellocal[@]}" "${plan_delremote[@]}"
  )
  if ((${#plan[@]} == 0)); then
    ((dry)) || __ui_info "nothing selected; no changes"
    return 0
  fi

  if ((dry)); then
    __ui_head "Planned changes (dry run):"
  else
    __ui_head "Planned changes:"
  fi
  for entry in "${plan[@]}"; do
    printf '  git %s\n' "${entry//$'\t'/ }"
  done
  ((dry)) && return 0

  local -a yflag=()
  ((yes)) && yflag=(--yes)
  __ui_confirm "Apply these ${#plan[@]} change(s)?" "${yflag[@]}"
  case $? in
  0) ;;
  1)
    __ui_info "git-branch-sync: aborted"
    return 0
    ;;
  *)
    __ui_err "git-branch-sync: refusing to apply without a TTY confirmation; pass --yes"
    return 2
    ;;
  esac

  local applied=0 fails=0 err
  local -a argv
  for entry in "${plan[@]}"; do
    IFS=$'\t' read -ra argv <<<"$entry"
    if err=$(command git "${argv[@]}" 2>&1 >/dev/null); then
      applied=$((applied + 1))
    else
      fails=$((fails + 1))
      __ui_warn "failed: git ${argv[*]} — ${err%%$'\n'*}"
    fi
  done
  __log_info "git-branch-sync: applied plan" "remote=$remote applied=$applied failed=$fails"
  __ui_status ok "applied $applied/${#plan[@]} change(s)"
  ((fails == 0)) || return 1
}
