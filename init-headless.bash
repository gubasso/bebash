# shellcheck shell=bash
: 'desc: headless bebash loader for standalone commands'

# A bebash-aware standalone command sources this at its top to obtain the
# framework's environment, eager output libs, and autoloaded functions/libs
# WITHOUT the interactive layer. rc.d/* is intentionally not sourced here: PATH
# wiring and other interactive side effects belong to interactive `init.bash`.
# It self-locates BEBASH_LIB so a command launched outside an interactive bebash
# shell still bootstraps.

__bebash_headless_source_dir() {
  local src=${BASH_SOURCE[0]}
  while [[ -L "$src" ]]; do
    local dir
    dir=$(cd -P -- "$(dirname -- "$src")" && pwd)
    src=$(readlink -- "$src")
    [[ "$src" != /* ]] && src=$dir/$src
  done
  cd -P -- "$(dirname -- "$src")" && pwd
}

BEBASH_LIB=${BEBASH_LIB:-$(__bebash_headless_source_dir)}
BEBASH_CONFIG_DIR=${BEBASH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bebash}
BEBASH_DATA_DIR=${BEBASH_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bebash}
export BEBASH_LIB BEBASH_CONFIG_DIR BEBASH_DATA_DIR

# shellcheck source=lib/log.bash
source "$BEBASH_LIB/lib/log.bash"
# shellcheck source=lib/ui.bash
source "$BEBASH_LIB/lib/ui.bash"
# shellcheck source=lib/helpers.bash
source "$BEBASH_LIB/lib/helpers.bash"
# shellcheck source=lib/autoload.bash
source "$BEBASH_LIB/lib/autoload.bash"

__autoload_scan_dir function "$BEBASH_LIB/functions"
__autoload_scan_dir lib "$BEBASH_LIB/lib"
__autoload_scan_dir function "$BEBASH_DATA_DIR/functions"
__autoload_scan_dir lib "$BEBASH_DATA_DIR/lib"

# Declarative overlay config is safe headless (unlike rc.d/*).
if [[ -r "$BEBASH_CONFIG_DIR/config.bash" ]]; then
  # shellcheck source=/dev/null
  source "$BEBASH_CONFIG_DIR/config.bash"
fi

if [[ -d "$BEBASH_CONFIG_DIR/disabled.d" ]]; then
  for __bebash_disabled in "$BEBASH_CONFIG_DIR/disabled.d"/*; do
    [[ -e "$__bebash_disabled" ]] || continue
    __bebash_disabled=${__bebash_disabled##*/}
    __bebash_disabled=${__bebash_disabled%.bash}
    unset -f "$__bebash_disabled" 2>/dev/null || true
  done
fi

unset -f __bebash_headless_source_dir
unset __bebash_disabled 2>/dev/null || true
