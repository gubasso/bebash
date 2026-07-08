# shellcheck shell=bash
: 'desc: single-user nix path fallback'

command -v nix >/dev/null 2>&1 && return 0

for __nix_profile in \
  "${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/etc/profile.d/nix.sh" \
  "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
  if [[ -r "$__nix_profile" ]]; then
    # shellcheck source=/dev/null
    source "$__nix_profile"
    break
  fi
done
unset __nix_profile
