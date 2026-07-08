# shellcheck shell=bash
: 'desc: prompt integration'

if __require starship; then
  __is_tty && export STARSHIP_CONFIG="$HOME/.config/starship-tty.toml"
  __cached_init starship starship init bash --print-full-init
else
  PS1='\W > '
fi
