#!/usr/bin/env bash
# Install Nix + Home Manager and apply the packages/shell setup, WITHOUT
# symlinking the repo configs in home-manager/config (~/.config/*, ~/.zsh/*).
# Generated shell files (~/.zshrc, ~/.bashrc, ...) are still managed.
# Uses the `pn-nolinks` flake output. No clone needed:
#   bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/nix-only.sh)
# (`curl ... | bash` also works.) Run from a checkout, it uses the local flake
# instead of the GitHub one.
set -euo pipefail

SRC="${BASH_SOURCE[0]:-}"
if [[ -n "$SRC" && -f "$(dirname "$SRC")/home-manager/flake.nix" ]]; then
  FLAKE_REF="$(cd "$(dirname "$SRC")" && pwd)/home-manager"
else
  FLAKE_REF="github:duskoide/dotfiles?dir=home-manager"
fi

load_nix_profile() {
  command -v nix &>/dev/null && return 0
  for profile in \
    "$HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    # shellcheck disable=SC1090
    [[ -r "$profile" ]] && . "$profile"
  done
  return 0
}

load_nix_profile

if ! command -v curl &>/dev/null; then
  echo "!! curl is required." >&2
  exit 1
fi

# --- Nix ---------------------------------------------------------------------
if ! command -v nix &>/dev/null; then
  echo "==> Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  load_nix_profile
else
  echo "==> Nix already installed."
fi
if ! command -v nix &>/dev/null; then
  echo "!! nix not on PATH; start a new shell and rerun." >&2
  exit 1
fi

# --- Flakes ------------------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
  echo "==> Enabled flakes in nix.conf."
fi

# --- Home Manager ------------------------------------------------------------
if ! command -v home-manager &>/dev/null; then
  echo "==> Installing home-manager..."
  # Priority 6 avoids a clash with the home-manager-path HM installs (see bootstrap.sh).
  nix profile install nixpkgs#home-manager --priority 6
else
  echo "==> home-manager already installed."
fi

# --- Switch (no dotfile links) -----------------------------------------------
echo "==> Running home-manager switch (pn-nolinks)..."
home-manager switch -b hm-backup --flake "$FLAKE_REF#pn-nolinks" --show-trace

# --- Login shell -------------------------------------------------------------
# Must be a system zsh listed in /etc/shells (not the Nix one), or display
# managers like SDDM refuse the login.
SYSTEM_ZSH=""
for candidate in /usr/bin/zsh /bin/zsh; do
  [[ -x "$candidate" ]] && { SYSTEM_ZSH="$candidate"; break; }
done

if [[ -n "$SYSTEM_ZSH" ]]; then
  if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$SYSTEM_ZSH" ]]; then
    if ! grep -qxF "$SYSTEM_ZSH" /etc/shells 2>/dev/null; then
      echo "==> Adding $SYSTEM_ZSH to /etc/shells (needs sudo)..."
      echo "$SYSTEM_ZSH" | sudo tee -a /etc/shells >/dev/null || true
    fi
    chsh -s "$SYSTEM_ZSH" && echo "==> Login shell set to zsh (next login)." \
      || echo "!! chsh failed; run: chsh -s $SYSTEM_ZSH" >&2
  else
    echo "==> Login shell already $SYSTEM_ZSH."
  fi
else
  echo "!! No system zsh found; install it, then: chsh -s /usr/bin/zsh" >&2
fi

echo "==> Done. Dotfiles were NOT linked; open a new shell."
