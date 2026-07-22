#!/usr/bin/env bash
# One-step bootstrap for a fresh machine.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
set -euo pipefail

DOTFILES_REPO="https://github.com/duskoide/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# --- 0. Precheck required commands ------------------------------------------
missing=()
for cmd in curl git; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if ((${#missing[@]})); then
  echo "!! Missing required command(s): ${missing[*]}" >&2
  echo "   Install them first, e.g.:" >&2
  echo "     Fedora: sudo dnf install -y ${missing[*]}" >&2
  echo "     Debian: sudo apt install -y ${missing[*]}" >&2
  exit 1
fi

# --- 1. Install Nix (single-user) -------------------------------------------
if ! command -v nix &>/dev/null; then
  echo "==> Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  # shellcheck disable=SC1091
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
else
  echo "==> Nix already installed."
fi

# --- 2. Enable flakes --------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
  echo "==> Enabled flakes in nix.conf."
fi

# --- 3. Install home-manager -------------------------------------------------
if ! command -v home-manager &>/dev/null; then
  echo "==> Installing home-manager..."
  nix profile install nixpkgs#home-manager
else
  echo "==> home-manager already installed."
fi

# --- 4. Clone dotfiles -------------------------------------------------------
if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "==> Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> Dotfiles already present, pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
fi

# --- 5. Link home-manager config into place ----------------------------------
mkdir -p "$HOME/.config"
ln -sfn "$DOTFILES_DIR/home-manager" "$HOME/.config/home-manager"
echo "==> Symlinked ~/.config/home-manager -> $DOTFILES_DIR/home-manager"

# --- 6. Build ----------------------------------------------------------------
echo "==> Running home-manager switch..."
home-manager switch --flake "$HOME/.config/home-manager#pn" --show-trace

echo ""
echo "========================================="
echo " Done! Open a new shell to get started."
echo ""
echo " Next steps:"
echo "   1. Recreate secrets:  nvim ~/dotfiles/shell/.zsh/secrets.zsh"
echo "   2. Set a Rust toolchain:  rustup default stable"
echo "   3. Auth GitHub (git credential helper needs it):  gh auth login"
echo "========================================="
