# shellcheck shell=bash
: 'desc: unified GitHub and GitLab branch-protection setup'

[[ -n "${__bebash_git_branch_protection_loaded:-}" ]] && return 0
__bebash_git_branch_protection_loaded=1

declare -gA __GIT_BRANCH_PROTECTION_GLOBAL=(
  [json]=0
  [verbosity]=0
  [yes]=0
  [non_interactive]=0
  [color]=auto
)
declare -ga __GIT_BRANCH_PROTECTION_EVENT_ACTIONS=()
declare -ga __GIT_BRANCH_PROTECTION_EVENT_STATUSES=()
declare -ga __GIT_BRANCH_PROTECTION_EVENT_OUTPUTS=()

__git_branch_protection_json_string() {
  local value=${1-}
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\b'/\\b}
  value=${value//$'\f'/\\f}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  # Escape any remaining C0 control character (U+0000..U+001F) as \u00XX so the
  # result is always valid JSON per RFC 8259, even if a payload smuggles one in.
  local ctrl rest
  for ctrl in $'\x01' $'\x02' $'\x03' $'\x04' $'\x05' $'\x06' $'\x07' \
    $'\x0b' $'\x0e' $'\x0f' $'\x10' $'\x11' $'\x12' $'\x13' $'\x14' $'\x15' \
    $'\x16' $'\x17' $'\x18' $'\x19' $'\x1a' $'\x1b' $'\x1c' $'\x1d' $'\x1e' $'\x1f'; do
    [[ $value == *"$ctrl"* ]] || continue
    printf -v rest '\\u%04x' "'$ctrl"
    value=${value//"$ctrl"/$rest}
  done
  printf '"%s"' "$value"
}

__git_branch_protection_json_array_from_csv() {
  local csv=${1-}
  jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))' <<<"$csv"
}

__git_branch_protection_event() {
  local action=${1-} status=${2-} output=${3-}
  __GIT_BRANCH_PROTECTION_EVENT_ACTIONS+=("$action")
  __GIT_BRANCH_PROTECTION_EVENT_STATUSES+=("$status")
  __GIT_BRANCH_PROTECTION_EVENT_OUTPUTS+=("$output")
}

__git_branch_protection_events_json() {
  local i
  printf '['
  for i in "${!__GIT_BRANCH_PROTECTION_EVENT_ACTIONS[@]}"; do
    ((i)) && printf ','
    printf '{"action":%s,"status":%s,"raw_output":%s}' \
      "$(__git_branch_protection_json_string "${__GIT_BRANCH_PROTECTION_EVENT_ACTIONS[i]}")" \
      "$(__git_branch_protection_json_string "${__GIT_BRANCH_PROTECTION_EVENT_STATUSES[i]}")" \
      "$(__git_branch_protection_json_string "${__GIT_BRANCH_PROTECTION_EVENT_OUTPUTS[i]}")"
  done
  printf ']'
}

__git_branch_protection_emit_json() {
  local provider=$1 target=$2 verb=$3 status=${4:-ok} extra=${5:-}
  printf '{"provider":%s,"target":%s,"verb":%s,"status":%s' \
    "$(__git_branch_protection_json_string "$provider")" \
    "$(__git_branch_protection_json_string "$target")" \
    "$(__git_branch_protection_json_string "$verb")" \
    "$(__git_branch_protection_json_string "$status")"
  [[ -n "$extra" ]] && printf ',%s' "$extra"
  printf ',"events":'
  __git_branch_protection_events_json
  printf '}\n'
}

__git_branch_protection_is_json() {
  [[ "${__GIT_BRANCH_PROTECTION_GLOBAL[json]}" == 1 ]]
}

__git_branch_protection_silent() {
  ((__GIT_BRANCH_PROTECTION_GLOBAL[verbosity] <= -2)) || __git_branch_protection_is_json
}

__git_branch_protection_quiet() {
  ((__GIT_BRANCH_PROTECTION_GLOBAL[verbosity] <= -1)) || __git_branch_protection_is_json
}

__git_branch_protection_info() {
  __git_branch_protection_quiet && return 0
  __ui_info "$@"
}

__git_branch_protection_step() {
  __git_branch_protection_quiet && return 0
  __ui_status info "== $* =="
}

__git_branch_protection_ok() {
  ((__GIT_BRANCH_PROTECTION_GLOBAL[verbosity] >= 1)) || return 0
  __git_branch_protection_is_json && return 0
  __ui_ok "$@"
}

__git_branch_protection_warn() {
  __git_branch_protection_silent && return 0
  __ui_warn "$@"
}

__git_branch_protection_error() {
  ((__GIT_BRANCH_PROTECTION_GLOBAL[verbosity] <= -2)) || __ui_err "$@"
  __log_err "$@"
}

__git_branch_protection_hint() {
  __git_branch_protection_quiet && return 0
  __ui_hint "$@"
}

# Load-bearing post-apply follow-up the API cannot perform (copy the workflow,
# flip host toggles). Unlike advisory hints, these survive -q: silencing them
# would leave a repo half-configured with no reminder. Suppressed only under
# -qq/--silent or --json.
__git_branch_protection_nextstep() {
  __git_branch_protection_silent && return 0
  __ui_hint "$@"
}

__git_branch_protection_die() {
  local code=${1:-1}
  shift || true
  __git_branch_protection_error "$*"
  return "$code"
}

__git_branch_protection_usage() {
  printf 'Usage:\n'
  printf '  git-branch-protection [global flags] gh   <owner/repo>    [apply] [--required-checks a,b] [--bypass-actor-id ID] [--default-branch develop]\n'
  printf '  git-branch-protection [global flags] gh   <owner/repo>    verify\n'
  printf '  git-branch-protection [global flags] gh   <owner/repo>    lookup\n'
  printf '  git-branch-protection [global flags] glab <group/project> [apply] [--tier free|premium] [--bot-user-id ID] [--merge-method ff] [--tag-pattern v*] [--default-branch develop]\n'
  printf '  git-branch-protection [global flags] glab <group/project> verify\n'
  printf '\n'
  printf 'Global flags:\n'
  printf '  --json                  Emit a structured summary on stdout.\n'
  printf '  -v, -vv                 Increase terminal detail.\n'
  printf '  -q, --quiet, --silent   Reduce terminal UI.\n'
  printf '  --color MODE            auto, always, or never.\n'
  printf '  -y, --yes               Accept prompts where supported.\n'
  printf '  --non-interactive       Never prompt.\n'
  printf '  -h, --help              Show this help.\n'
}

__git_branch_protection_apply_color() {
  case "${__GIT_BRANCH_PROTECTION_GLOBAL[color]}" in
    always) export FORCE_COLOR=1 ;;
    never) export NO_COLOR=1 ;;
    auto) ;;
  esac
}

__git_branch_protection_parse_common() {
  local -a rest=()
  while (($#)); do
    case "$1" in
      --json) __GIT_BRANCH_PROTECTION_GLOBAL[json]=1 ;;
      -v) __GIT_BRANCH_PROTECTION_GLOBAL[verbosity]=1 ;;
      -vv) __GIT_BRANCH_PROTECTION_GLOBAL[verbosity]=2 ;;
      -q | --quiet) __GIT_BRANCH_PROTECTION_GLOBAL[verbosity]=-1 ;;
      --silent) __GIT_BRANCH_PROTECTION_GLOBAL[verbosity]=-2 ;;
      --color)
        shift
        (($#)) || __git_branch_protection_die 2 "--color requires auto, always, or never" || return $?
        case "$1" in
          auto | always | never) __GIT_BRANCH_PROTECTION_GLOBAL[color]=$1 ;;
          *) __git_branch_protection_die 2 "unknown color mode: $1" || return $? ;;
        esac
        ;;
      --color=*)
        case "${1#--color=}" in
          auto | always | never) __GIT_BRANCH_PROTECTION_GLOBAL[color]=${1#--color=} ;;
          *) __git_branch_protection_die 2 "unknown color mode: ${1#--color=}" || return $? ;;
        esac
        ;;
      -y | --yes) __GIT_BRANCH_PROTECTION_GLOBAL[yes]=1 ;;
      --non-interactive) __GIT_BRANCH_PROTECTION_GLOBAL[non_interactive]=1 ;;
      -h | --help)
        rest+=(help)
        shift
        rest+=("$@")
        break
        ;;
      --)
        shift
        rest+=("$@")
        break
        ;;
      *)
        rest+=("$@")
        break
        ;;
    esac
    shift
  done
  __GIT_BRANCH_PROTECTION_ARGV=("${rest[@]}")
  __git_branch_protection_apply_color
}

__git_branch_protection_run() {
  local action=$1
  shift
  local output rc=0
  if __git_branch_protection_is_json; then
    output=$("$@" 2>&1) || rc=$?
    __git_branch_protection_event "$action" "$([[ $rc -eq 0 ]] && printf ok || printf failed)" "$output"
    if ((rc != 0)); then
      __log_err "git-branch-protection step failed" "action=$action exit=$rc"
      return "$rc"
    fi
    return 0
  fi

  "$@"
}

__git_branch_protection_run_allow_fail() {
  local action=$1
  shift
  local output rc=0
  if __git_branch_protection_is_json; then
    output=$("$@" 2>&1) || rc=$?
    __git_branch_protection_event "$action" "$([[ $rc -eq 0 ]] && printf ok || printf ignored)" "$output"
    return 0
  fi

  "$@" || true
}

__git_branch_protection_rulesets_dir() {
  # Overlay overrides native, as a whole subtree. Prefer the user's overlay
  # ($BEBASH_DATA_DIR/artifacts/...) when that directory exists; otherwise use
  # the shipped native payload ($BEBASH_LIB/artifacts/...). A present-but-partial
  # overlay is validated (and fails closed) by __git_branch_protection_validate_rulesets;
  # native files are never merged in. See ADR-0035.
  local overlay="${BEBASH_DATA_DIR}/artifacts/git-branch-protection/rulesets"
  local native="${BEBASH_LIB}/artifacts/git-branch-protection/rulesets"
  if [[ -d "$overlay" ]]; then
    printf '%s\n' "$overlay"
  else
    printf '%s\n' "$native"
  fi
}

__git_branch_protection_validate_rulesets() {
  local dir=$1 file
  for file in master.json develop.json tags.json; do
    if [[ ! -r "$dir/$file" ]]; then
      __git_branch_protection_error "Ruleset artifact is missing or unreadable: $dir/$file"
      __git_branch_protection_hint "Check for a broken bebash data overlay first; otherwise reinstall bebash so native artifacts are installed."
      return 1
    fi
    jq empty "$dir/$file" >/dev/null || {
      __git_branch_protection_error "Ruleset artifact is not valid JSON: $dir/$file"
      return 1
    }
  done
}

__git_branch_protection_required_checks_json() {
  local required_checks=${1-}
  printf '%s' "$required_checks" |
    jq -Rc 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)) | map({context: .})'
}

__git_branch_protection_gh_payload() {
  local payload=$1 add_checks=${2:-} required_checks=${3:-} bypass_actor_id=${4:-}
  local filter='.'
  local -a jq_args=()
  local checks_json

  # The bypass actor is particular per-repo runtime data — never baked into the
  # shipped artifact. When an id is supplied, construct the full entry here (an
  # installed GitHub App: actor_type Integration, always-bypass).
  if [[ -n "$bypass_actor_id" ]]; then
    # shellcheck disable=SC2016 # $id is a jq variable supplied with --arg.
    filter='.bypass_actors = [{"actor_id": ($id | tonumber), "actor_type": "Integration", "bypass_mode": "always"}]'
    jq_args+=(--arg id "$bypass_actor_id")
  fi
  if [[ "$add_checks" == checks && -n "$required_checks" ]]; then
    checks_json=$(__git_branch_protection_required_checks_json "$required_checks")
    filter="${filter} | .rules += [{\"type\":\"required_status_checks\",\"parameters\":{\"required_status_checks\":\$checks,\"strict_required_status_checks_policy\":true}}]"
    jq_args+=(--argjson checks "$checks_json")
  fi

  jq "${jq_args[@]}" "$filter" "$payload"
}

__git_branch_protection_gh_apply_ruleset() {
  local owner_repo=$1 payload=$2 add_checks=${3:-} required_checks=${4:-} bypass_actor_id=${5:-}
  __git_branch_protection_gh_payload "$payload" "$add_checks" "$required_checks" "$bypass_actor_id" |
    gh api -X POST "/repos/${owner_repo}/rulesets" --input -
}

__git_branch_protection_gh_run_ruleset() {
  local action=$1 owner_repo=$2 payload=$3 add_checks=${4:-} required_checks=${5:-} bypass_actor_id=${6:-}
  local output rc=0
  if __git_branch_protection_is_json; then
    output=$(__git_branch_protection_gh_apply_ruleset "$owner_repo" "$payload" "$add_checks" "$required_checks" "$bypass_actor_id" 2>&1) || rc=$?
    __git_branch_protection_event "$action" "$([[ $rc -eq 0 ]] && printf ok || printf failed)" "$output"
    if ((rc != 0)); then
      __log_err "git-branch-protection step failed" "action=$action exit=$rc"
      return "$rc"
    fi
    return 0
  fi

  __git_branch_protection_gh_apply_ruleset "$owner_repo" "$payload" "$add_checks" "$required_checks" "$bypass_actor_id"
}

__git_branch_protection_gh_lookup() {
  local owner_repo=$1
  local output app_id rc=0

  __log_info "github branch-protection lookup" "repo=$owner_repo"
  app_id=$(gh api "/repos/${owner_repo}/installation" --jq '.app_id' 2>/dev/null) || rc=$?

  if __git_branch_protection_is_json; then
    if ((rc == 0)) && [[ -n "$app_id" && "$app_id" != null ]]; then
      output="installed-app	${app_id}	Integration	(pass as --bypass-actor-id)"
    else
      output='installed-app	(none resolved — install your GitHub App on the repo)'
    fi
    __git_branch_protection_event "lookup" ok "$output"
    __git_branch_protection_emit_json gh "$owner_repo" lookup ok
    return 0
  fi

  __ui_head "GitHub bypass actor lookup"
  if ((rc == 0)) && [[ -n "$app_id" && "$app_id" != null ]]; then
    __ui_field 16 "installed-app" "${app_id}  Integration  pass as --bypass-actor-id"
  else
    __git_branch_protection_warn "No installed GitHub App resolved for $owner_repo"
    __git_branch_protection_hint "Install your GitHub App on the repo, then re-run lookup; check gh authentication and access."
  fi
}

__git_branch_protection_gh_verify() {
  local owner_repo=$1
  __log_info "github branch-protection verify" "repo=$owner_repo"
  __git_branch_protection_step "GitHub rulesets"
  __git_branch_protection_run "ruleset list" gh ruleset list -R "$owner_repo" || return $?
  __git_branch_protection_step "Applicable to master"
  __git_branch_protection_run_allow_fail "ruleset check master" gh ruleset check master -R "$owner_repo"
  __git_branch_protection_step "Applicable to develop"
  __git_branch_protection_run_allow_fail "ruleset check develop" gh ruleset check develop -R "$owner_repo"
}

__git_branch_protection_gh_apply() {
  local owner_repo=$1 required_checks=${2:-} bypass_actor_id=${3:-} default_branch=${4:-develop}
  local rulesets_dir

  __require_verbose gh jq || return 1
  rulesets_dir=$(__git_branch_protection_rulesets_dir)
  __git_branch_protection_validate_rulesets "$rulesets_dir" || return 1

  # The protected default branch needs a bypass actor so CI can fast-forward it.
  # That id is particular runtime data: prefer the explicit flag, otherwise
  # auto-resolve the repo's installed GitHub App. Never fall back to a baked
  # default — on a personal account the global github-actions app is rejected
  # (HTTP 422), and on any account the right actor is the user's own App.
  if [[ -z "$bypass_actor_id" ]]; then
    __git_branch_protection_step "Resolving bypass actor (installed GitHub App)"
    bypass_actor_id=$(gh api "/repos/${owner_repo}/installation" --jq '.app_id' 2>/dev/null || printf '')
  fi
  if [[ -z "$bypass_actor_id" || "$bypass_actor_id" == null ]]; then
    __git_branch_protection_error "No bypass actor for ${owner_repo}: none supplied and no installed GitHub App could be resolved."
    __git_branch_protection_hint "Install your GitHub App on the repo, or find its id with: git-branch-protection gh $owner_repo lookup"
    __git_branch_protection_hint "Then re-run with: --bypass-actor-id <app-id>"
    return 1
  fi

  __log_info "github branch-protection apply" "repo=$owner_repo default_branch=$default_branch"
  # master.json's ~DEFAULT_BRANCH target is a GitHub ruleset special-ref literal;
  # --default-branch only drives gh repo edit and must not rewrite the payload.
  __git_branch_protection_step "Applying master-protection"
  __git_branch_protection_gh_run_ruleset "apply master-protection" "$owner_repo" "$rulesets_dir/master.json" checks "$required_checks" "$bypass_actor_id" || return $?
  __git_branch_protection_step "Applying develop-protection"
  # develop carries no bypass actor (humans open PRs into it); only the
  # protected default branch needs one for CI to push.
  __git_branch_protection_gh_run_ruleset "apply develop-protection" "$owner_repo" "$rulesets_dir/develop.json" checks "$required_checks" '' || return $?
  __git_branch_protection_step "Applying release-tags"
  __git_branch_protection_gh_run_ruleset "apply release-tags" "$owner_repo" "$rulesets_dir/tags.json" '' "$required_checks" "$bypass_actor_id" || return $?
  __git_branch_protection_step "Setting default branch -> $default_branch"
  __git_branch_protection_run "set default branch" gh repo edit "$owner_repo" --default-branch "$default_branch" || return $?
  __git_branch_protection_gh_verify "$owner_repo" || return $?

  if __git_branch_protection_is_json; then
    __git_branch_protection_emit_json gh "$owner_repo" apply ok \
      "\"default_branch\":$(__git_branch_protection_json_string "$default_branch"),\"required_checks\":$(__git_branch_protection_json_array_from_csv "$required_checks")"
  else
    __ui_head "Done"
    __ui_field 18 "Repository" "$owner_repo"
    __ui_field 18 "Default branch" "$default_branch"
    __ui_field 18 "Required checks" "${required_checks:-none}"
    __git_branch_protection_nextstep "Copy github/workflows/release-promote.yml into .github/workflows/release-promote.yml."
    __git_branch_protection_nextstep "Enable Actions read/write permissions and allow Actions to create pull requests."
  fi
}

__git_branch_protection_gh() {
  local owner_repo=$1 verb=${2:-apply}
  shift 2 || true
  local required_checks='' bypass_actor_id='' default_branch=develop

  while (($#)); do
    case "$1" in
      --required-checks)
        shift
        (($#)) || __git_branch_protection_die 2 "--required-checks requires a comma-separated value" || return $?
        required_checks=$1
        ;;
      --required-checks=*) required_checks=${1#--required-checks=} ;;
      --bypass-actor-id)
        shift
        (($#)) || __git_branch_protection_die 2 "--bypass-actor-id requires an integer id" || return $?
        bypass_actor_id=$1
        ;;
      --bypass-actor-id=*) bypass_actor_id=${1#--bypass-actor-id=} ;;
      --default-branch)
        shift
        (($#)) || __git_branch_protection_die 2 "--default-branch requires a branch name" || return $?
        default_branch=$1
        ;;
      --default-branch=*) default_branch=${1#--default-branch=} ;;
      *) __git_branch_protection_die 2 "unknown GitHub option: $1" || return $? ;;
    esac
    shift
  done

  case "$verb" in
    apply) __git_branch_protection_gh_apply "$owner_repo" "$required_checks" "$bypass_actor_id" "$default_branch" ;;
    verify)
      __require_verbose gh jq || return 1
      __git_branch_protection_gh_verify "$owner_repo"
      __git_branch_protection_is_json && __git_branch_protection_emit_json gh "$owner_repo" verify ok
      ;;
    lookup)
      __require_verbose gh jq || return 1
      __git_branch_protection_gh_lookup "$owner_repo"
      ;;
    *) __git_branch_protection_die 2 "unknown GitHub verb: $verb" ;;
  esac
}

__git_branch_protection_glab_project_id() {
  local project=$1 encoded
  encoded=$(printf '%s' "$project" | jq -sRr @uri)
  glab api "projects/${encoded}" --jq '.id'
}

__git_branch_protection_glab_apply() {
  local project=$1 tier=${2:-free} bot_user_id=${3:-} merge_method=${4:-ff} tag_pattern=${5:-v*} default_branch=${6:-develop}
  local project_id pattern develop_branch_id

  __require_verbose glab jq || return 1
  case "$tier" in
    free | premium) ;;
    *) __git_branch_protection_die 2 "--tier must be free or premium" || return $? ;;
  esac

  project_id=$(__git_branch_protection_glab_project_id "$project") || return $?
  __log_info "gitlab branch-protection apply" "project=$project project_id=$project_id tier=$tier"
  __git_branch_protection_info "GitLab project id: $project_id"

  __git_branch_protection_step "Preparing master protection"
  __git_branch_protection_run_allow_fail "delete default master protection" glab api -X DELETE "projects/${project_id}/protected_branches/master"
  if [[ "$tier" == premium ]]; then
    if [[ -z "$bot_user_id" ]]; then
      pattern="${BOT_PATTERN:-project_.*_bot|group_.*_bot}"
      bot_user_id=$(glab api "projects/${project_id}/members/all" \
        --jq ".[] | select(.username|test(\"${pattern}\")) | .id" | head -n 1)
      if [[ -z "$bot_user_id" ]]; then
        __git_branch_protection_error "Could not resolve GitLab bot user id."
        __git_branch_protection_hint "Pass --bot-user-id <id>, or set BOT_PATTERN to match the project/group bot username."
        return 1
      fi
      __git_branch_protection_info "GitLab bot user id: $bot_user_id"
    fi
    __git_branch_protection_run "protect master" glab api -X POST "projects/${project_id}/protected_branches" \
      -H 'Content-Type: application/json' --input - <<EOF
{
  "name": "master",
  "allowed_to_push":      [{"user_id": ${bot_user_id}}],
  "allowed_to_merge":     [{"user_id": ${bot_user_id}}, {"access_level": 40}],
  "allowed_to_unprotect": [{"access_level": 40}],
  "allow_force_push": false,
  "code_owner_approval_required": true
}
EOF
    __git_branch_protection_run_allow_fail "configure push rules" glab api -X POST "projects/${project_id}/push_rule" \
      -f deny_delete_tag=true -f member_check=true \
      -f prevent_secrets=true -f reject_unsigned_commits=true
  else
    __git_branch_protection_run "protect master" glab api -X POST "projects/${project_id}/protected_branches" \
      -f name=master -f push_access_level=0 -f merge_access_level=40 \
      -f unprotect_access_level=40 -f allow_force_push=false \
      -f code_owner_approval_required=true
  fi

  __git_branch_protection_step "Protecting develop"
  __git_branch_protection_run "protect develop" glab api -X POST "projects/${project_id}/protected_branches" \
    -f name=develop -f push_access_level=0 -f merge_access_level=30 \
    -f unprotect_access_level=40 -f allow_force_push=false \
    -f code_owner_approval_required=false

  if [[ "$tier" == premium ]]; then
    develop_branch_id=$(glab api "projects/${project_id}/protected_branches/develop" --jq '.id') || return $?
    __git_branch_protection_step "Configuring approvals"
    __git_branch_protection_run "configure approvals" glab api -X PUT "projects/${project_id}/approvals" \
      -f reset_approvals_on_push=true \
      -f disable_overriding_approvers_per_merge_request=true \
      -f merge_requests_author_approval=false \
      -f merge_requests_disable_committers_approval=true
    __git_branch_protection_run "create dev-review approval rule" glab api -X POST "projects/${project_id}/approval_rules" \
      -f name='dev-review' -f approvals_required=1 \
      -f applies_to_all_protected_branches=false \
      -f "protected_branch_ids[]=${develop_branch_id}"
  fi

  __git_branch_protection_step "Configuring merge-request hygiene"
  __git_branch_protection_run "configure project merge settings" glab api -X PUT "projects/${project_id}" \
    -f only_allow_merge_if_pipeline_succeeds=true \
    -f only_allow_merge_if_all_discussions_are_resolved=true \
    -f "merge_method=${merge_method}"

  __git_branch_protection_step "Protecting release tags"
  __git_branch_protection_run "protect release tags" glab api -X POST "projects/${project_id}/protected_tags" \
    -f "name=${tag_pattern}" -f create_access_level=40

  __git_branch_protection_step "Setting default branch -> $default_branch"
  __git_branch_protection_run "set default branch" glab api -X PUT "projects/${project_id}" -f "default_branch=${default_branch}"
  __git_branch_protection_glab_verify_by_id "$project" "$project_id"

  if __git_branch_protection_is_json; then
    __git_branch_protection_emit_json glab "$project" apply ok \
      "\"project_id\":$(__git_branch_protection_json_string "$project_id"),\"tier\":$(__git_branch_protection_json_string "$tier"),\"default_branch\":$(__git_branch_protection_json_string "$default_branch"),\"tag_pattern\":$(__git_branch_protection_json_string "$tag_pattern")"
  else
    __ui_head "Done"
    __ui_field 18 "Project" "$project"
    __ui_field 18 "Project id" "$project_id"
    __ui_field 18 "Tier" "$tier"
    __ui_field 18 "Default branch" "$default_branch"
    __git_branch_protection_nextstep "Create a Project Access Token with Maintainer role and write_repository scope for the CI push bot."
    __git_branch_protection_nextstep "For GitLab 17.2+, enable CI/CD job-token Git push requests."
    __git_branch_protection_nextstep "Copy gitlab/ci/release-promote.gitlab-ci.yml into the project CI configuration."
  fi
}

__git_branch_protection_glab_verify_by_id() {
  local project=$1 project_id=$2
  __log_info "gitlab branch-protection verify" "project=$project project_id=$project_id"
  __git_branch_protection_step "GitLab protected branches"
  __git_branch_protection_run "protected branches" glab api "projects/${project_id}/protected_branches" || return $?
  __git_branch_protection_step "GitLab protected tags"
  __git_branch_protection_run "protected tags" glab api "projects/${project_id}/protected_tags" || return $?
  __git_branch_protection_step "GitLab push rules"
  if __git_branch_protection_is_json; then
    __git_branch_protection_run_allow_fail "push rules" glab api "projects/${project_id}/push_rule"
  else
    glab api "projects/${project_id}/push_rule" || printf '%s\n' '(none; requires Premium)'
  fi
}

__git_branch_protection_glab_verify() {
  local project=$1 project_id
  __require_verbose glab jq || return 1
  project_id=$(__git_branch_protection_glab_project_id "$project") || return $?
  __git_branch_protection_glab_verify_by_id "$project" "$project_id"
  __git_branch_protection_is_json && __git_branch_protection_emit_json glab "$project" verify ok \
    "\"project_id\":$(__git_branch_protection_json_string "$project_id")"
}

__git_branch_protection_glab() {
  local project=$1 verb=${2:-apply}
  shift 2 || true
  local tier=free bot_user_id='' merge_method=ff tag_pattern='v*' default_branch=develop

  while (($#)); do
    case "$1" in
      --tier)
        shift
        (($#)) || __git_branch_protection_die 2 "--tier requires free or premium" || return $?
        tier=$1
        ;;
      --tier=*) tier=${1#--tier=} ;;
      --bot-user-id)
        shift
        (($#)) || __git_branch_protection_die 2 "--bot-user-id requires an integer id" || return $?
        bot_user_id=$1
        ;;
      --bot-user-id=*) bot_user_id=${1#--bot-user-id=} ;;
      --merge-method)
        shift
        (($#)) || __git_branch_protection_die 2 "--merge-method requires ff, rebase_merge, or merge" || return $?
        merge_method=$1
        ;;
      --merge-method=*) merge_method=${1#--merge-method=} ;;
      --tag-pattern)
        shift
        (($#)) || __git_branch_protection_die 2 "--tag-pattern requires a protected tag glob" || return $?
        tag_pattern=$1
        ;;
      --tag-pattern=*) tag_pattern=${1#--tag-pattern=} ;;
      --default-branch)
        shift
        (($#)) || __git_branch_protection_die 2 "--default-branch requires a branch name" || return $?
        default_branch=$1
        ;;
      --default-branch=*) default_branch=${1#--default-branch=} ;;
      *) __git_branch_protection_die 2 "unknown GitLab option: $1" || return $? ;;
    esac
    shift
  done

  case "$verb" in
    apply) __git_branch_protection_glab_apply "$project" "$tier" "$bot_user_id" "$merge_method" "$tag_pattern" "$default_branch" ;;
    verify) __git_branch_protection_glab_verify "$project" ;;
    lookup) __git_branch_protection_die 2 "GitLab lookup is not supported; pass --bot-user-id for premium projects when needed." ;;
    *) __git_branch_protection_die 2 "unknown GitLab verb: $verb" ;;
  esac
}

__git_branch_protection_main() {
  __GIT_BRANCH_PROTECTION_ARGV=()
  __GIT_BRANCH_PROTECTION_EVENT_ACTIONS=()
  __GIT_BRANCH_PROTECTION_EVENT_STATUSES=()
  __GIT_BRANCH_PROTECTION_EVENT_OUTPUTS=()
  __git_branch_protection_parse_common "$@" || return $?

  local provider=${__GIT_BRANCH_PROTECTION_ARGV[0]:-}
  if [[ -z "$provider" || "$provider" == help ]]; then
    __git_branch_protection_usage
    return 0
  fi
  if ((${#__GIT_BRANCH_PROTECTION_ARGV[@]} < 2)); then
    __git_branch_protection_usage >&2
    __git_branch_protection_die 2 "missing target for provider: $provider"
    return $?
  fi

  local target=${__GIT_BRANCH_PROTECTION_ARGV[1]}
  local verb=apply rest_start=2
  if ((${#__GIT_BRANCH_PROTECTION_ARGV[@]} >= 3)) && [[ "${__GIT_BRANCH_PROTECTION_ARGV[2]}" != -* ]]; then
    verb=${__GIT_BRANCH_PROTECTION_ARGV[2]}
    rest_start=3
  fi
  local -a rest=("${__GIT_BRANCH_PROTECTION_ARGV[@]:$rest_start}")

  case "$provider" in
    gh) __git_branch_protection_gh "$target" "$verb" "${rest[@]}" ;;
    glab) __git_branch_protection_glab "$target" "$verb" "${rest[@]}" ;;
    *) __git_branch_protection_die 2 "unknown provider: $provider (expected gh or glab)" ;;
  esac
}
