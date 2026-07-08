# shellcheck shell=bash
: 'desc: shell options and history defaults'

set -o vi
shopt -s histappend checkwinsize globstar cdspell dirspell 2>/dev/null || true

HISTSIZE=5000
HISTFILESIZE=10000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE='ls:ll:cd:pwd:exit:clear:cl'
