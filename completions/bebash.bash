# shellcheck shell=bash
: 'desc: bash completion for the bebash CLI'

__bebash_completion_payload_root() {
  if [[ -n "${BEBASH_LIB:-}" ]]; then
    printf '%s\n' "$BEBASH_LIB"
    return 0
  fi
  local cmd
  cmd=$(command -v bebash 2>/dev/null) || return 1
  local src=$cmd
  while [[ -L "$src" ]]; do
    local dir
    dir=$(cd -P -- "$(dirname -- "$src")" && pwd) || return 1
    src=$(readlink -- "$src") || return 1
    [[ "$src" != /* ]] && src=$dir/$src
  done
  local bin_dir
  bin_dir=$(cd -P -- "$(dirname -- "$src")" && pwd) || return 1
  cd -P -- "$bin_dir/.." && pwd
}

__bebash_completion_functions() {
  local root data dir file name
  root=$(__bebash_completion_payload_root 2>/dev/null || true)
  data=${BEBASH_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bebash}
  for dir in "${root:+$root/functions}" "$data/functions"; do
    [[ -n "$dir" && -d "$dir" ]] || continue
    for file in "$dir"/*.bash; do
      [[ -e "$file" ]] || continue
      name=${file##*/}
      printf '%s\n' "${name%.bash}"
    done
  done | LC_ALL=C sort -u
}

__bebash_completion() {
  local cur prev sub i word
  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD - 1]}
  local commands='doctor list path edit init man version help'
  local global_flags='--json -v -vv -q --quiet --silent --color -y --yes --non-interactive -h --help --version'

  case "$prev" in
  --color)
    mapfile -t COMPREPLY < <(compgen -W 'auto always never' -- "$cur")
    return 0
    ;;
  esac

  # Global flags may precede the subcommand (parsed before dispatch), so scan
  # from index 1, skipping global flags and --color's argument, to find the
  # first non-flag word: the active subcommand. Stop before the word being
  # completed so a partial current word is not mistaken for the subcommand.
  sub=''
  for ((i = 1; i < COMP_CWORD; i++)); do
    word=${COMP_WORDS[i]}
    if [[ "$word" == "--color" ]]; then
      ((i++)) # skip its argument
      continue
    fi
    [[ "$word" == -* ]] && continue
    sub=$word
    break
  done

  if [[ -z "$sub" ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$commands $global_flags" -- "$cur")
    return 0
  fi
  case "$prev" in
  --location)
    mapfile -t COMPREPLY < <(compgen -W 'xdg dotfiles custom' -- "$cur")
    return 0
    ;;
  --scope)
    mapfile -t COMPREPLY < <(compgen -W 'all payload user' -- "$cur")
    return 0
    ;;
  esac

  case "$sub" in
  edit | list)
    mapfile -t COMPREPLY < <(compgen -W "$(__bebash_completion_functions)" -- "$cur")
    ;;
  init)
    mapfile -t COMPREPLY < <(compgen -W '--location --path --refresh-docs --no-doctor -h --help' -- "$cur")
    ;;
  doctor)
    mapfile -t COMPREPLY < <(compgen -W '--json --logs --no-tools --scope -h --help' -- "$cur")
    ;;
  man)
    mapfile -t COMPREPLY < <(compgen -W '--source -h --help' -- "$cur")
    ;;
  help)
    mapfile -t COMPREPLY < <(compgen -W "$commands" -- "$cur")
    ;;
  *)
    mapfile -t COMPREPLY < <(compgen -W "$global_flags" -- "$cur")
    ;;
  esac
}

complete -F __bebash_completion bebash
