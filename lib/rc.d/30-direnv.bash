# shellcheck shell=bash
: 'desc: direnv shell hook'

__require direnv || return 0

declare -F _direnv_hook >/dev/null || eval "$(direnv hook bash)"

if [[ -n "${DCTL_SANDBOX:-}" && -n "${BASH_EXECUTION_STRING:-}" ]]; then
  eval "$(direnv export bash)"
fi
