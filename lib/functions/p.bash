# shellcheck shell=bash
: 'desc: Fuzzy-cd into a git repository under configured project roots'

__p_usage() {
  cat <<'EOF'
usage: p [query]

Fuzzy-select a git repository from BEBASH_PROJECT_ROOTS and cd into it.
EOF
}

__p_roots() {
  if [[ -n "${BEBASH_PROJECT_ROOTS:-}" ]]; then
    local -a __p_root_items=()
    read -r -a __p_root_items <<<"$BEBASH_PROJECT_ROOTS"
    printf '%s\n' "${__p_root_items[@]}"
  else
    printf '%s\n' "$HOME/Projects"
  fi
}

__p_preview() {
  local d=${1:?directory required}
  if command git -C "$d" rev-parse --git-dir >/dev/null 2>&1; then
    local branch
    branch=$(command git -C "$d" symbolic-ref --short -q HEAD 2>/dev/null) ||
      branch=$(command git -C "$d" rev-parse --short HEAD 2>/dev/null) ||
      branch='?'
    local c='' r=''
    if __ui_use_color 1; then
      c=$(__ui_sgr head)
      r=$(__ui_sgr reset)
    fi
    printf '%s%s%s\n\n' "$c" "$branch" "$r"
  fi
  if [[ -f "$d/README.md" ]]; then
    command cat -- "$d/README.md"
  else
    command ls -la -- "$d"
  fi
}

p() {
  case "${1:-}" in
  -h | --help)
    __p_usage
    return 0
    ;;
  esac
  __require_verbose fd fzf awk || return 1
  local -a roots=()
  local root
  while IFS= read -r root; do
    [[ -d "$root" ]] && roots+=("$root")
  done < <(__p_roots)
  ((${#roots[@]})) || {
    __ui_err "p: no project roots found"
    return 1
  }

  export -f __p_preview __ui_use_color __ui_sgr
  local ui_lib=${BEBASH_LIB:-${BASH_SOURCE[0]%/lib/functions/p.bash}}/lib/ui.bash
  local preview="FORCE_COLOR=1 bash -c 'source \"$ui_lib\" 2>/dev/null; __p_preview \"\$1\"' fzf {2}"
  local sel
  sel=$(
    command fd --type d --hidden --glob '.git' --prune "${roots[@]}" 2>/dev/null |
      command awk -v h="$HOME" '{ f=$0; sub(/\/\.git\/?$/, "", f); d=f; if (index(d,h)==1) d="~" substr(d, length(h)+1); print d "\t" f }' |
      command fzf --delimiter "$(printf '\t')" --with-nth 1 --preview "$preview" ${1:+--query "$*"}
  ) || return 0
  [[ -n "$sel" ]] || return 0
  cd -- "${sel#*$'\t'}" || return 1
}
