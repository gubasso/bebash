# shellcheck shell=bash
: 'desc: GNU Stow dotfiles package manager'

[[ -n "${__bebash_dots_loaded:-}" ]] && return 0
__bebash_dots_loaded=1

__DOTS_VERSION="1.2.0"
__DOTS_STOW_IGNORE='(\.md$|^\.hooks$|^\.git$|^\.gitignore$|^\.gitmodules$|^_.*)'

declare -a __DOTS_EXEC_PLAN=()
declare -A __DOTS_EXEC_PLAN_DEPOF=()
declare -A __DOTS_SKIPPED_DEPS=()
declare -A __DOTS_SKIPPED_DIRECT=()
declare -a __DOTS_INTERACTIVE_SELECTION=()

__dots_reset_state() {
  __dots_verbose=0
  __dots_dry_run=0
  __dots_quiet=0
  __dots_auto_yes=0
  __dots_no_hooks=0
  __dots_force=0
  __dots_action="stow"
  __DOTS_EXEC_PLAN=()
  __DOTS_EXEC_PLAN_DEPOF=()
  __DOTS_SKIPPED_DEPS=()
  __DOTS_SKIPPED_DIRECT=()
  __DOTS_INTERACTIVE_SELECTION=()
}

__dots_err() { __ui_err "dots: $*"; }
__dots_warn() { __ui_warn "dots: $*"; }
__dots_log() { ((__dots_quiet == 0)) && __ui_info "$*" || true; }
__dots_log_verbose() { ((__dots_quiet == 0 && __dots_verbose >= 1)) && __ui_hint "$*" || true; }
__dots_log_debug() { ((__dots_quiet == 0 && __dots_verbose >= 2)) && __log_debug "dots: $*"; }
__dots_log_success() { ((__dots_quiet == 0)) && __ui_ok "$*" || true; }

__dots_usage() {
  cat >&2 <<'EOF'
dots - GNU Stow wrapper for dotfiles repository management

usage:
  dots [OPTIONS] [package]...        Stow packages from the configured repository
  dots -D|--delete <package>...      Unstow packages
  dots -R|--restow <package>...      Restow packages (delete + stow)
  dots --list                        List all available packages
  dots --sync                        Stow all packages

OPTIONS:
  --dir, --dotfiles-dir DIR
                    Use DIR as the package repository
  -n, --dry-run     Show preview only, make no changes
  -f, --force       Back up conflicting files and retry stow
  -y, --yes         Skip confirmation prompt
  -q, --quiet       Suppress non-essential output
  -v, --verbose     Enable verbose output (can be repeated)
  --no-hooks        Skip hook scripts and dependency resolution
  -h, --help        Show this help message
  --version         Show version

CONFIG:
  Repository resolution order: --dir/--dotfiles-dir, DOTFILES, BEBASH_DOTFILES_DIR.
EOF
}

__dots_resolve_repo() {
  local explicit_dir=$1
  if [[ -n "$explicit_dir" ]]; then
    DOTFILES=$explicit_dir
  elif [[ -n "${DOTFILES:-}" ]]; then
    : # use the inherited DOTFILES value as-is
  elif [[ -n "${BEBASH_DOTFILES_DIR:-}" ]]; then
    DOTFILES=$BEBASH_DOTFILES_DIR
  else
    __dots_err "dotfiles repository is not configured; set BEBASH_DOTFILES_DIR, DOTFILES, or pass --dir"
    return 2
  fi
  [[ -d "$DOTFILES" ]] || {
    __dots_err "repository not found: $DOTFILES"
    return 1
  }
  command git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1 || {
    __dots_err "repository is not a git working tree: $DOTFILES"
    return 1
  }
}

__dots_hooks_dir() {
  local package=$1
  printf '%s/%s/.hooks\n' "$DOTFILES" "$package"
}

__dots_hook_exists() {
  local package=$1 hook_name=$2
  [[ -x "$(__dots_hooks_dir "$package")/$hook_name" ]]
}

__dots_get_package_hooks() {
  local package=$1 hook_name
  local -a hooks=()
  for hook_name in pre-stow post-stow pre-unstow post-unstow; do
    __dots_hook_exists "$package" "$hook_name" && hooks+=("$hook_name")
  done
  printf '%s\n' "${hooks[*]}"
}

__dots_run_hook() {
  local package=$1 hook_name=$2 target_dir=$3 hook_path
  hook_path="$(__dots_hooks_dir "$package")/$hook_name"
  [[ -x "$hook_path" ]] || return 0

  __dots_log_verbose "Running $hook_name hook for $package"
  export DOTS_PACKAGE=$package
  export DOTS_TARGET=$target_dir
  export DOTS_ACTION=$__dots_action
  export DOTS_REPO=$DOTFILES
  "$hook_path"
  local rc=$?
  unset DOTS_PACKAGE DOTS_TARGET DOTS_ACTION DOTS_REPO
  return "$rc"
}

__dots_run_hooks_for_package() {
  local package=$1 hook_name=$2 target_dir=$3
  __dots_hook_exists "$package" "$hook_name" || return 0
  __dots_run_hook "$package" "$hook_name" "$target_dir"
}

__dots_get_dependencies() {
  local package=$1 depends_file line
  local -a deps=()
  depends_file="$(__dots_hooks_dir "$package")/depends"
  [[ -f "$depends_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    line=${line#"${line%%[![:space:]]*}"}
    line=${line%"${line##*[![:space:]]}"}
    [[ -n "$line" ]] && deps+=("$line")
  done <"$depends_file"
  printf '%s\n' "${deps[@]}" | LC_ALL=C command sort -u
}

__dots_detect_target() {
  local pkg_dir=$1 sys_path
  for sys_path in etc usr var opt; do
    [[ -d "$pkg_dir/$sys_path" ]] && {
      printf 'system\n'
      return 0
    }
  done
  printf 'user\n'
}

__dots_get_target_for_package() {
  local package=$1 target_type
  target_type=$(__dots_detect_target "$DOTFILES/$package")
  [[ "$target_type" == "system" ]] && printf '/\n' || printf '%s\n' "$HOME"
}

__dots_list_packages() {
  [[ -d "$DOTFILES" ]] || return 0
  command find "$DOTFILES" -maxdepth 1 -mindepth 1 -type d \
    ! -name '.*' \
    ! -name '_*' \
    -printf '%f\n' | LC_ALL=C command sort
}

__dots_package_exists() {
  local package=$1
  [[ -d "$DOTFILES/$package" ]]
}

__dots_validate_package() {
  local package=$1
  __dots_package_exists "$package" || {
    __dots_err "package '$package' not found in $DOTFILES"
    return 1
  }
}

__dots_visit_dependency() {
  local permissive=$1 pkg=$2 requester=${3:-}
  # visited_ref/dep_of_ref index into caller associative arrays via namerefs;
  # the nameref type is unresolvable here, so the string keys are misread as
  # arithmetic (SC2004). The $ is required for associative-array indexing.
  # shellcheck disable=SC2004
  local -n visited_ref=$4 dep_of_ref=$5 requested_ref=$6 result_ref=$7 path_ref=$8

  case "${visited_ref[$pkg]:-0}" in
  2)
    return 0
    ;;
  1)
    __dots_err "circular dependency detected: $pkg"
    return 1
    ;;
  esac

  visited_ref[pkg]=1
  path_ref+=("$pkg")

  if [[ -n "$requester" && -z "${dep_of_ref[$pkg]:-}" && -z "${requested_ref[$pkg]:-}" ]]; then
    dep_of_ref[pkg]=$requester
  fi

  if ! __dots_package_exists "$pkg"; then
    if ((permissive == 1)); then
      if [[ -z "$requester" ]]; then
        __DOTS_SKIPPED_DIRECT[$pkg]=1
      else
        __DOTS_SKIPPED_DEPS[$pkg]="${__DOTS_SKIPPED_DEPS[$pkg]:+${__DOTS_SKIPPED_DEPS[$pkg]}, }$requester"
      fi
      unset 'path_ref[-1]'
      visited_ref[pkg]=2
      return 0
    fi
    __dots_err "dependency '$pkg' not found in $DOTFILES"
    return 1
  fi

  local dep
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    __dots_visit_dependency "$permissive" "$dep" "$pkg" visited_ref dep_of_ref requested_ref result_ref path_ref || return 1
  done < <(__dots_get_dependencies "$pkg")

  unset 'path_ref[-1]'
  visited_ref[pkg]=2
  result_ref+=("$pkg")
}

__dots_resolve_all_dependencies() {
  local permissive=${1:-0}
  shift || true
  local -a requested=("$@") result=() path=()
  # visited/requested_set are consumed indirectly through namerefs in
  # __dots_visit_dependency (passed by name below); the indirect use is
  # untraceable statically (SC2034).
  # shellcheck disable=SC2034
  local -A requested_set=() visited=() dep_of=()
  local pkg
  for pkg in "${requested[@]}"; do
    # shellcheck disable=SC2034
    requested_set[$pkg]=1
  done
  for pkg in "${requested[@]}"; do
    __dots_visit_dependency "$permissive" "$pkg" "" visited dep_of requested_set result path || return 1
  done
  __DOTS_EXEC_PLAN=("${result[@]}")
  for pkg in "${result[@]}"; do
    __DOTS_EXEC_PLAN_DEPOF[$pkg]=${dep_of[$pkg]:-}
  done
}

__dots_is_stow_ignored() {
  local rel_path=$1 component
  local -a components=()
  IFS='/' read -r -a components <<<"$rel_path"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" =~ $__DOTS_STOW_IGNORE ]] && return 0
  done
  return 1
}

__dots_get_git_ignored_paths() {
  local package=$1 path
  command git -C "$DOTFILES" rev-parse --git-dir >/dev/null 2>&1 || return 0
  command git -C "$DOTFILES" ls-files --others --ignored --exclude-standard --directory \
    -- "$package/" 2>/dev/null | while IFS= read -r path; do
    printf '%s\n' "${path#"$package/"}"
  done
}

__dots_get_git_ignore_stow_args() {
  local package=$1 path
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    path=${path%/}
    path=$(printf '%s' "$path" | command sed 's/[][\\.*+?(){}^$|]/\\&/g')
    printf '%s\n' "--ignore=^${path}\$"
  done < <(__dots_get_git_ignored_paths "$package")
}

__dots_scan_package_files() {
  local package=$1 target_dir=$2 file
  local pkg_dir=$DOTFILES/$package
  [[ -d "$pkg_dir" ]] || return 0
  while IFS= read -r -d '' file; do
    local rel=${file#"$pkg_dir"/}
    __dots_is_stow_ignored "$rel" && continue
    local target_path=$target_dir/$rel
    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
      printf 'new\t%s\n' "$rel"
    elif [[ -L "$target_path" ]]; then
      local raw_target abs_target
      raw_target=$(command readlink "$target_path" 2>/dev/null) || raw_target=""
      if [[ "$raw_target" == /* ]]; then
        abs_target=$(command realpath -sm "$raw_target")
      else
        abs_target=$(command realpath -sm "$(dirname -- "$target_path")/$raw_target")
      fi
      if [[ "$abs_target" == "$file" ]]; then
        printf 'ok\t%s\n' "$rel"
      elif [[ "$abs_target" == "$DOTFILES/"* ]]; then
        printf 'update\t%s\n' "$rel"
      else
        printf 'conflict\t%s\n' "$rel"
      fi
    else
      printf 'conflict\t%s\n' "$rel"
    fi
  done < <(command find "$pkg_dir" \( -type f -o -type l \) -print0 2>/dev/null)
}

__dots_scan_stale_symlinks() {
  local package=$1 target_dir=$2 rel_dir target_path link link_target abs_target
  local pkg_dir=$DOTFILES/$package
  [[ -d "$pkg_dir" ]] || return 0
  while IFS= read -r -d '' rel_dir; do
    rel_dir=${rel_dir#"$pkg_dir"}
    rel_dir=${rel_dir#/}
    target_path=$target_dir
    [[ -n "$rel_dir" ]] && target_path=$target_dir/$rel_dir
    [[ -d "$target_path" ]] || continue
    while IFS= read -r -d '' link; do
      [[ -L "$link" && ! -e "$link" ]] || continue
      link_target=$(command readlink "$link" 2>/dev/null) || continue
      abs_target=$(cd -- "$(dirname -- "$link")" && command readlink -m "$link_target" 2>/dev/null) || continue
      [[ "$abs_target" == "$pkg_dir/"* ]] || continue
      printf 'stale\t%s\n' "${link#"$target_dir"/}"
    done < <(command find "$target_path" -maxdepth 1 -type l -print0 2>/dev/null)
  done < <(command find "$pkg_dir" -type d -print0 2>/dev/null)
}

__dots_show_package_preview() {
  local package=$1 action=$2 target_dir target_label dep_info hooks scan_output status path
  target_dir=$(__dots_get_target_for_package "$package")
  target_label="~"
  [[ "$target_dir" == "/" ]] && target_label="/ (system, requires sudo)"
  dep_info=""
  [[ -n "${__DOTS_EXEC_PLAN_DEPOF[$package]:-}" ]] && dep_info=" (dependency of: ${__DOTS_EXEC_PLAN_DEPOF[$package]})"

  printf '  %s -> %s%s\n' "$package" "$target_label" "$dep_info" >&2
  printf '     from: %s\n' "$DOTFILES" >&2
  if ((__dots_no_hooks == 0)); then
    hooks=$(__dots_get_package_hooks "$package")
    [[ -n "$hooks" ]] && printf '     hooks: %s\n' "$hooks" >&2
  fi

  scan_output=$(__dots_scan_package_files "$package" "$target_dir")
  local count_new=0 count_ok=0 count_conflict=0 count_update=0
  local -a conflict_files=()
  while IFS=$'\t' read -r status path; do
    [[ -z "$status" ]] && continue
    case "$status" in
    new) ((++count_new)) ;;
    ok) ((++count_ok)) ;;
    conflict)
      ((++count_conflict))
      conflict_files+=("$path")
      ;;
    update) ((++count_update)) ;;
    esac
  done <<<"$scan_output"

  local stale_output count_stale=0
  local -a stale_files=()
  stale_output=$(__dots_scan_stale_symlinks "$package" "$target_dir")
  while IFS=$'\t' read -r status path; do
    [[ "$status" == "stale" ]] || continue
    ((++count_stale))
    stale_files+=("$path")
  done <<<"$stale_output"

  printf '     files: %d new, %d ok, %d update, %d conflict, %d stale\n' \
    "$count_new" "$count_ok" "$count_update" "$count_conflict" "$count_stale" >&2
  local f
  for f in "${conflict_files[@]}"; do
    printf '        [conflict] %s\n' "$f" >&2
  done
  for f in "${stale_files[@]}"; do
    printf '        [stale] %s\n' "$f" >&2
  done
  if ((count_conflict > 0 && __dots_force == 0)); then
    __dots_warn "conflicts will block stow for $package (use --force to override)"
  fi
}

__dots_show_preview() {
  local action=$1 pkg
  printf 'dots: %s preview\n' "${action^^}" >&2
  for pkg in "${__DOTS_EXEC_PLAN[@]}"; do
    __dots_show_package_preview "$pkg" "$action"
  done
}

__dots_show_skipped_deps_warning() {
  local -A all_skipped=()
  local pkg
  for pkg in "${!__DOTS_SKIPPED_DEPS[@]}"; do all_skipped[$pkg]=1; done
  for pkg in "${!__DOTS_SKIPPED_DIRECT[@]}"; do all_skipped[$pkg]=1; done
  ((${#all_skipped[@]})) || return 0
  __dots_warn "skipped missing packages:"
  for pkg in "${!all_skipped[@]}"; do
    if [[ -n "${__DOTS_SKIPPED_DIRECT[$pkg]:-}" ]]; then
      __ui_hint "$pkg (requested directly)"
    else
      __ui_hint "$pkg (needed by: ${__DOTS_SKIPPED_DEPS[$pkg]})"
    fi
  done
}

__dots_confirm_action() {
  local action=$1
  ((__dots_auto_yes == 1)) && return 0
  __ui_confirm "Proceed with $action?"
}

__dots_build_stow_cmd() {
  local target_dir=$1
  printf '%s\n' stow
  printf '%s\n' "--ignore=$__DOTS_STOW_IGNORE"
  ((__dots_verbose >= 1)) && printf '%s\n' "--verbose=$__dots_verbose"
  ((__dots_dry_run == 1)) && printf '%s\n' "--simulate"
  printf '%s\n' "--target=$target_dir"
}

__dots_run_cmd() {
  local target_dir=$1
  shift
  if [[ "$target_dir" == "/" ]]; then
    command sudo "$@"
  else
    "$@"
  fi
}

__dots_run_stow() {
  local action=$1 repo_dir=$2 package=$3 target_dir=$4
  local -a cmd=()
  mapfile -t cmd < <(__dots_build_stow_cmd "$target_dir")
  if [[ "$action" == "-S" ]]; then
    local -a git_ignore_args=()
    mapfile -t git_ignore_args < <(__dots_get_git_ignore_stow_args "$package")
    ((${#git_ignore_args[@]})) && cmd+=("${git_ignore_args[@]}")
  fi
  cmd+=(--dir="$repo_dir" "$action" "$package")
  __dots_log_debug "running: ${cmd[*]}"
  __dots_run_cmd "$target_dir" "${cmd[@]}"
}

__dots_parse_stow_conflicts() {
  local stderr=$1
  printf '%s\n' "$stderr" | command sed -n \
    -e 's/.*existing target is not owned by stow: \(.*\)/\1/p' \
    -e 's/.*over existing target \(.*\) since neither a link.*/\1/p' \
    -e 's/.*existing target is neither a link nor a directory: \(.*\)/\1/p'
}

__dots_backup_conflicting_files() {
  local target_dir=$1 conflict_paths=$2 timestamp rel_path
  timestamp=$(command date +%Y-%m-%dT%H-%M-%S)
  while IFS= read -r rel_path; do
    [[ -z "$rel_path" ]] && continue
    local full_path=$target_dir/$rel_path backup_path=$target_dir/$rel_path.bkp.$timestamp
    [[ -e "$full_path" || -L "$full_path" ]] || continue
    __dots_log "Backing up: $rel_path -> ${rel_path}.bkp.${timestamp}"
    __dots_run_cmd "$target_dir" command mv -- "$full_path" "$backup_path" || return 1
  done <<<"$conflict_paths"
}

__dots_stow_with_force() {
  local repo_dir=$1 package=$2 target_dir=$3 stow_output conflicts
  if stow_output=$(__dots_run_stow -S "$repo_dir" "$package" "$target_dir" 2>&1); then
    [[ -n "$stow_output" ]] && printf '%s\n' "$stow_output" >&2
    return 0
  fi
  conflicts=$(__dots_parse_stow_conflicts "$stow_output")
  [[ -n "$conflicts" ]] || {
    printf '%s\n' "$stow_output" >&2
    return 1
  }
  ((__dots_force == 1)) || {
    printf '%s\n' "$stow_output" >&2
    __dots_err "conflicts prevent stowing '$package'; use --force to back up conflicting files and retry"
    return 1
  }
  __dots_log "Conflicts detected, backing up..."
  __dots_backup_conflicting_files "$target_dir" "$conflicts" || return 1
  stow_output=$(__dots_run_stow -S "$repo_dir" "$package" "$target_dir" 2>&1) || {
    printf '%s\n' "$stow_output" >&2
    return 1
  }
  [[ -n "$stow_output" ]] && printf '%s\n' "$stow_output" >&2
  return 0
}

__dots_cleanup_broken_symlinks() {
  local package=$1 target_dir=$2 rel_dir target_path link link_target abs_target removed=0
  local pkg_dir=$DOTFILES/$package
  [[ -d "$pkg_dir" ]] || return 0
  while IFS= read -r -d '' rel_dir; do
    rel_dir=${rel_dir#"$pkg_dir"}
    rel_dir=${rel_dir#/}
    target_path=$target_dir
    [[ -n "$rel_dir" ]] && target_path=$target_dir/$rel_dir
    [[ -d "$target_path" ]] || continue
    while IFS= read -r -d '' link; do
      [[ -L "$link" && ! -e "$link" ]] || continue
      link_target=$(command readlink "$link" 2>/dev/null) || continue
      abs_target=$(cd -- "$(dirname -- "$link")" && command readlink -m "$link_target" 2>/dev/null) || continue
      [[ "$abs_target" == "$pkg_dir/"* ]] || continue
      if ((__dots_dry_run == 1)); then
        __dots_log "[dry-run] Would remove stale symlink: ${link#"$target_dir"/}"
      else
        __dots_log_verbose "Removing stale symlink: ${link#"$target_dir"/}"
        __dots_run_cmd "$target_dir" command rm -- "$link" || return 1
      fi
      ((++removed))
    done < <(command find "$target_path" -maxdepth 1 -type l -print0 2>/dev/null)
  done < <(command find "$pkg_dir" -type d -print0 2>/dev/null)
  ((removed > 0)) && __dots_log_verbose "Removed $removed stale symlink(s)"
  return 0
}

__dots_do_stow_package() {
  local package=$1 target_dir
  __dots_validate_package "$package" || return 1
  target_dir=$(__dots_get_target_for_package "$package")
  __dots_log "Stowing package: $package (target: $target_dir)"
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" pre-stow "$target_dir" || {
      __dots_err "pre-stow hook failed for '$package'"
      return 1
    }
  fi
  __dots_log_verbose "From: $DOTFILES"
  __dots_stow_with_force "$DOTFILES" "$package" "$target_dir" || {
    __dots_err "failed to stow '$package' from $DOTFILES"
    return 1
  }
  __dots_cleanup_broken_symlinks "$package" "$target_dir" || return 1
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" post-stow "$target_dir" ||
      __dots_warn "post-stow hook failed for '$package'"
  fi
  __dots_log_success "Stowed: $package"
}

__dots_do_unstow_package() {
  local package=$1 target_dir
  __dots_validate_package "$package" || return 1
  target_dir=$(__dots_get_target_for_package "$package")
  __dots_log "Unstowing package: $package"
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" pre-unstow "$target_dir" || {
      __dots_err "pre-unstow hook failed for '$package'"
      return 1
    }
  fi
  __dots_run_stow -D "$DOTFILES" "$package" "$target_dir" >/dev/null 2>&1 || true
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" post-unstow "$target_dir" ||
      __dots_warn "post-unstow hook failed for '$package'"
  fi
  __dots_log_success "Unstowed: $package"
}

__dots_do_restow_package() {
  local package=$1 target_dir
  __dots_validate_package "$package" || return 1
  target_dir=$(__dots_get_target_for_package "$package")
  __dots_log "Restowing package: $package"
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" pre-unstow "$target_dir" || {
      __dots_err "pre-unstow hook failed for '$package'"
      return 1
    }
  fi
  __dots_run_stow -D "$DOTFILES" "$package" "$target_dir" >/dev/null 2>&1 || true
  if ((__dots_no_hooks == 0)); then
    __dots_run_hooks_for_package "$package" post-unstow "$target_dir" ||
      __dots_warn "post-unstow hook failed for '$package'"
  fi
  __dots_do_stow_package "$package"
}

__dots_show_available_packages() {
  local package
  while IFS= read -r package; do
    [[ -n "$package" ]] && printf '%s\n' "$package"
  done < <(__dots_list_packages)
}

__dots_get_all_packages() {
  __dots_list_packages
}

__dots_select_packages_interactive() {
  local -a available=()
  __DOTS_INTERACTIVE_SELECTION=()
  mapfile -t available < <(__dots_get_all_packages)
  ((${#available[@]})) || {
    __dots_err "no packages found for selection"
    return 1
  }
  command -v fzf >/dev/null 2>&1 || {
    __dots_err "fzf not found; specify package names explicitly"
    return 1
  }
  [[ -t 0 ]] || {
    __dots_err "interactive mode requires a terminal; specify package names explicitly or use --sync"
    return 2
  }
  local selected fzf_rc=0
  selected=$(printf '%s\n' "${available[@]}" | command fzf --multi \
    --height=~50% \
    --layout=reverse \
    --border \
    --prompt="Select packages: " \
    --header="TAB: multi-select, ENTER: confirm, ESC: cancel") || fzf_rc=$?
  [[ $fzf_rc -eq 0 ]] || return 1
  mapfile -t __DOTS_INTERACTIVE_SELECTION <<<"$selected"
  ((${#__DOTS_INTERACTIVE_SELECTION[@]}))
}

__dots_validate_packages_or_die() {
  local -a requested=("$@") invalid=()
  local pkg
  for pkg in "${requested[@]}"; do
    __dots_package_exists "$pkg" || invalid+=("$pkg")
  done
  ((${#invalid[@]} == 0)) && return 0
  __dots_err "unknown package(s): ${invalid[*]}"
  __dots_show_available_packages >&2
  return 1
}

__dots_parse_args() {
  local -n __dots_packages_ref=$1
  local -n __dots_dir_ref=$2
  shift 2
  while (($#)); do
    case "$1" in
    -h | --help)
      __dots_usage
      return 10
      ;;
    --version)
      printf 'dots version %s\n' "$__DOTS_VERSION"
      return 10
      ;;
    --dir | --dotfiles-dir)
      (($# >= 2)) || {
        __dots_err "$1 requires a directory"
        return 2
      }
      __dots_dir_ref=$2
      shift 2
      ;;
    --dir=* | --dotfiles-dir=*)
      __dots_dir_ref=${1#*=}
      shift
      ;;
    -n | --dry-run | --simulate)
      __dots_dry_run=1
      shift
      ;;
    -y | --yes)
      __dots_auto_yes=1
      shift
      ;;
    -q | --quiet)
      __dots_quiet=1
      shift
      ;;
    -v | --verbose)
      ((++__dots_verbose))
      shift
      ;;
    -vv)
      __dots_verbose=2
      shift
      ;;
    -vvv)
      __dots_verbose=3
      shift
      ;;
    -D | --delete)
      __dots_action="delete"
      shift
      ;;
    -R | --restow)
      __dots_action="restow"
      shift
      ;;
    -S | --stow)
      __dots_action="stow"
      shift
      ;;
    --list)
      __dots_action="list"
      shift
      ;;
    --sync)
      __dots_action="sync"
      shift
      ;;
    --no-hooks)
      __dots_no_hooks=1
      shift
      ;;
    -f | --force)
      __dots_force=1
      shift
      ;;
    -*)
      __dots_err "unknown option: $1"
      return 2
      ;;
    *)
      __dots_packages_ref+=("$1")
      shift
      ;;
    esac
  done
}

dots::main() {
  __dots_reset_state
  local -a packages=()
  local explicit_dir="" parse_rc=0

  __dots_parse_args packages explicit_dir "$@" || parse_rc=$?
  [[ $parse_rc -eq 10 ]] && return 0
  [[ $parse_rc -eq 0 ]] || return "$parse_rc"

  __require_verbose stow git || return 1
  __dots_resolve_repo "$explicit_dir" || return $?

  if [[ "$__dots_action" == "list" ]]; then
    __dots_show_available_packages
    return 0
  fi

  if [[ "$__dots_action" == "sync" ]]; then
    mapfile -t packages < <(__dots_get_all_packages)
    ((${#packages[@]})) || {
      __dots_err "no packages found to sync"
      return 1
    }
  fi

  if ((${#packages[@]} == 0)); then
    case "$__dots_action" in
    stow | delete | restow)
      __dots_select_packages_interactive || return $?
      packages=("${__DOTS_INTERACTIVE_SELECTION[@]}")
      ((${#packages[@]})) || return 0
      ;;
    *)
      __dots_usage
      return 2
      ;;
    esac
  fi

  __dots_validate_packages_or_die "${packages[@]}" || return 1

  if ((__dots_no_hooks == 0)) && [[ "$__dots_action" == "stow" || "$__dots_action" == "sync" || "$__dots_action" == "restow" ]]; then
    local permissive=0
    [[ "$__dots_action" == "sync" ]] && permissive=1
    __dots_resolve_all_dependencies "$permissive" "${packages[@]}" || return 1
  else
    __DOTS_EXEC_PLAN=("${packages[@]}")
    local pkg
    for pkg in "${packages[@]}"; do
      __DOTS_EXEC_PLAN_DEPOF[$pkg]=""
    done
  fi

  ((__dots_quiet == 0)) && __dots_show_preview "$__dots_action"
  __dots_show_skipped_deps_warning

  if ((__dots_dry_run == 1)); then
    ((__dots_quiet == 0)) && __ui_hint "dry-run mode - no changes made, hooks not executed"
    return 0
  fi

  __dots_confirm_action "$__dots_action" || {
    __ui_info "Aborted."
    return 0
  }

  local pkg
  for pkg in "${__DOTS_EXEC_PLAN[@]}"; do
    case "$__dots_action" in
    stow | sync) __dots_do_stow_package "$pkg" || return 1 ;;
    delete) __dots_do_unstow_package "$pkg" || return 1 ;;
    restow)
      if [[ -z "${__DOTS_EXEC_PLAN_DEPOF[$pkg]:-}" ]]; then
        __dots_do_restow_package "$pkg" || return 1
      else
        __dots_do_stow_package "$pkg" || return 1
      fi
      ;;
    esac
  done
}
