# shellcheck shell=bash
: 'desc: zoxide shell integration'

__require zoxide || return 0
__cached_init zoxide zoxide init bash
