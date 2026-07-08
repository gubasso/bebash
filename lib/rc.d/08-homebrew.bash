# shellcheck shell=bash
: 'desc: homebrew shell environment'

__brew_bin=''
__brew_candidates=(
  "${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/bin/brew}"
  /home/linuxbrew/.linuxbrew/bin/brew
  /opt/homebrew/bin/brew
  /usr/local/bin/brew
)

for __brew_candidate in "${__brew_candidates[@]}"; do
  if [[ -n "$__brew_candidate" && -x "$__brew_candidate" ]]; then
    __brew_bin=$__brew_candidate
    break
  fi
done

[[ -z "$__brew_bin" ]] && __brew_bin=$(command -v brew 2>/dev/null || true)
[[ -z "$__brew_bin" ]] && {
  unset __brew_bin __brew_candidates __brew_candidate
  return 0
}

__path_prepend "${__brew_bin%/bin/brew}/sbin"
__path_prepend "${__brew_bin%/bin/brew}/bin"
__cached_init brew "$__brew_bin" shellenv bash || eval "$("$__brew_bin" shellenv bash)"

unset __brew_bin __brew_candidates __brew_candidate
