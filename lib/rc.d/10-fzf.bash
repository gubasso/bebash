# shellcheck shell=bash
: 'desc: fzf shell integration'

__require fzf || return 0

__fzf_ver=$(command fzf --version 2>/dev/null) || return 0
__fzf_ver=${__fzf_ver%% *}
__fzf_minor=${__fzf_ver#0.}
__fzf_minor=${__fzf_minor%%.*}
if [[ ${__fzf_ver%%.*} -eq 0 && $__fzf_minor -lt 48 ]]; then
  unset __fzf_ver __fzf_minor
  return 0
fi
unset __fzf_ver __fzf_minor

export FZF_DEFAULT_OPTS=" \
  --height=40% \
  --layout=reverse \
  --border=rounded \
  --info=inline-right \
  --marker='▏' \
  --pointer='▌' \
  --prompt='  ' \
  --bind='ctrl-/:toggle-preview' \
  --bind='ctrl-d:half-page-down' \
  --bind='ctrl-u:half-page-up' \
"
export FZF_CTRL_T_OPTS=" \
  --walker-skip .git,node_modules,target,.venv,__pycache__ \
  --preview 'bat -n --color=always --line-range :500 {} 2>/dev/null || cat {}' \
  --bind 'ctrl-/:change-preview-window(down|hidden|)' \
"
export FZF_ALT_C_OPTS=" \
  --walker-skip .git,node_modules,target,.venv,__pycache__ \
  --preview 'ls -1 --color=always {} | head -50' \
"

__cached_init fzf fzf --bash

export FZF_COMPLETION_AUTO_COMMON_PREFIX=true
export FZF_COMPLETION_AUTO_COMMON_PREFIX_PART=true

__fzf_tab_script=''
for __fzf_tab_candidate in \
  "${BEBASH_FZF_TAB_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fzf-tab-completion}/bash/fzf-bash-completion.sh" \
  /usr/share/fzf-tab-completion/bash/fzf-bash-completion.sh \
  /usr/local/share/fzf-tab-completion/bash/fzf-bash-completion.sh \
  /opt/homebrew/share/fzf-tab-completion/bash/fzf-bash-completion.sh; do
  if [[ -r "$__fzf_tab_candidate" ]]; then
    __fzf_tab_script=$__fzf_tab_candidate
    break
  fi
done

if [[ -n "$__fzf_tab_script" ]]; then
  # shellcheck source=/dev/null
  source "$__fzf_tab_script"
  if [[ $- == *i* ]]; then
    bind '"\e[0n": complete' 2>/dev/null || true
    __fzf_tab_or_trigger() {
      local trigger=${FZF_COMPLETION_TRIGGER-**}
      if [[ "${READLINE_LINE:0:$READLINE_POINT}" == *"$trigger" ]]; then
        builtin printf '\033[5n'
      else
        fzf_bash_completion
      fi
    }
    bind -x '"\t": __fzf_tab_or_trigger' 2>/dev/null || true
  fi
elif [[ -z "${__BEBASH_FZF_TAB_WARNED:-}" ]]; then
  __BEBASH_FZF_TAB_WARNED=1
  __ui_info "fzf-tab-completion not found; TAB uses menu-complete fallback"
fi

unset __fzf_tab_script __fzf_tab_candidate
