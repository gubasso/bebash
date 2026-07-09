# shellcheck shell=bash
: 'desc: expose the bebash-managed commands dir on PATH'

# bebash owns a commands lane separate from the user's plain ~/.local/bin:
# standalone, bebash-aware commands live in $BEBASH_DATA_DIR/commands and are
# put on PATH here (not via per-command symlinks). __path_prepend no-ops when
# the dir is absent and dedupes.
__path_prepend "${BEBASH_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bebash}/commands"
