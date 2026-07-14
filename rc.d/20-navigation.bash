# shellcheck shell=bash
: 'desc: generic interactive navigation ergonomics'

[[ $- == *i* ]] || return 0

shopt -s autocd direxpand cdable_vars 2>/dev/null || true
