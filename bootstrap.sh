#!/usr/bin/env bash
# One-step bootstrap for a fresh machine.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
set -euo pipefail

DOTFILES_REPO="https://github.com/duskoide/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# --- 0. Load nix into PATH if already installed -----------------------------
# The guard below relies on `command -v nix`, but the Nix profile dir is only
# added to PATH by sourcing a profile script (login-shell .bash_profile isn't
# sourced in every context). Support both single-user and daemon installs.
load_nix_profile() {
  if command -v nix &>/dev/null; then
    return 0
  fi

  for profile in \
    "$HOME/.nix-profile/etc/profile.d/nix.sh" \
    "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"; do
    if [[ -r "$profile" ]]; then
      # shellcheck disable=SC1090
      . "$profile"
    fi
  done
}

load_nix_profile

# --- 1. Precheck required commands ------------------------------------------
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

# --- 2. Install Nix (single-user) -------------------------------------------
if ! command -v nix &>/dev/null; then
  echo "==> Installing Nix..."
  sh <(curl -L https://nixos.org/nix/install) --no-daemon
  load_nix_profile
else
  echo "==> Nix already installed."
fi

if ! command -v nix &>/dev/null; then
  echo "!! Nix installation completed, but the nix command is not available." >&2
  echo "   Start a new shell and rerun this script." >&2
  exit 1
fi

# --- 3. Enable flakes --------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
  echo "==> Enabled flakes in nix.conf."
fi

# --- 4. Install home-manager -------------------------------------------------
if ! command -v home-manager &>/dev/null; then
  echo "==> Installing home-manager..."
  # Priority 6: `home-manager switch` (flake mode) installs its own
  # `home-manager-path` into the default profile at priority 5 during
  # activation, and two same-name packages at the same priority conflict
  # ("profile ... is incompatible" / "conflicting packages"). Different
  # priorities coexist, and the flake-input home-manager wins on PATH.
  nix profile install nixpkgs#home-manager --priority 6
else
  echo "==> home-manager already installed."
fi

# --- 5. Clone dotfiles -------------------------------------------------------
if [[ ! -d "$DOTFILES_DIR" ]]; then
  echo "==> Cloning dotfiles..."
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
else
  echo "==> Dotfiles already present, pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only
fi

# --- 6. Link home-manager config into place ----------------------------------
mkdir -p "$HOME/.config"
ln -sfn "$DOTFILES_DIR/home-manager" "$HOME/.config/home-manager"
echo "==> Symlinked ~/.config/home-manager -> $DOTFILES_DIR/home-manager"

# --- 7. Prepare local secrets ------------------------------------------------
# secrets.zsh is intentionally ignored and therefore absent after a fresh
# clone. Home Manager links it into ~/.zsh, so ensure the source exists before
# activation without overwriting an existing private file.
SECRETS_FILE="$DOTFILES_DIR/home-manager/config/zsh/secrets.zsh"
if [[ ! -e "$SECRETS_FILE" && ! -L "$SECRETS_FILE" ]]; then
  cat > "$SECRETS_FILE" <<'EOF'
# Put private tokens / API keys here.
# This file is ignored by Git and sourced by Zsh.
EOF
  chmod 600 "$SECRETS_FILE"
  echo "==> Created private secrets template at $SECRETS_FILE"
else
  echo "==> Keeping existing secrets file at $SECRETS_FILE"
fi

# --- 8. Build ----------------------------------------------------------------
echo "==> Running home-manager switch..."
# Home Manager now owns ~/.bashrc, ~/.bash_profile and ~/.profile; -b moves any
# pre-existing distro copies aside as *.hm-backup instead of failing.
home-manager switch -b hm-backup --flake "$HOME/.config/home-manager#pn" --show-trace

# --- 9. Set zsh as the login shell ------------------------------------------
# Home Manager configures zsh (programs.zsh) but never runs chsh, so a fresh
# machine keeps logging into bash. The system zsh reads all the HM-managed zsh
# files (which load Nix via hm-session-vars), so making zsh the login shell is
# what gets nix/home-manager onto PATH after relogin.
#
# IMPORTANT: use a *system* zsh that is listed in /etc/shells, NOT the
# Nix-profile zsh (~/.nix-profile/bin/zsh). Display managers such as SDDM
# validate the login shell against /etc/shells and refuse shells living under
# $HOME, which locks you out of the graphical session
# ("Login for <user> is disabled").
SYSTEM_ZSH=""
for candidate in /usr/bin/zsh /bin/zsh; do
  if [[ -x "$candidate" ]]; then
    SYSTEM_ZSH="$candidate"
    break
  fi
done

if [[ -n "$SYSTEM_ZSH" ]]; then
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" != "$SYSTEM_ZSH" ]]; then
    # chsh requires the target shell to be listed in /etc/shells.
    if ! grep -qxF "$SYSTEM_ZSH" /etc/shells 2>/dev/null; then
      echo "==> Adding $SYSTEM_ZSH to /etc/shells (needs sudo)..."
      echo "$SYSTEM_ZSH" | sudo tee -a /etc/shells >/dev/null || true
    fi
    echo "==> Setting login shell to $SYSTEM_ZSH..."
    if chsh -s "$SYSTEM_ZSH"; then
      echo "==> Login shell set to zsh. Takes effect on next login."
    else
      echo "!! Could not change login shell automatically." >&2
      echo "   Run manually:  chsh -s $SYSTEM_ZSH" >&2
    fi
  else
    echo "==> Login shell already $SYSTEM_ZSH."
  fi
else
  echo "!! No system zsh found in /usr/bin or /bin; skipping chsh." >&2
  echo "   Install zsh via your distro, then run:  chsh -s /usr/bin/zsh" >&2
fi

echo ""
echo "========================================="
echo " Done! Open a new shell to get started."
echo ""
echo " Next steps:"
echo "   1. Edit secrets:  nvim ~/dotfiles/home-manager/config/zsh/secrets.zsh"
echo "   2. Set default Rust toolchain:  rustup default stable"
echo "   3. Authenticate GitHub:  gh auth login"
echo "   4. Install Zen browser (RPM providing zen-browser.desktop) if missing"
echo "========================================="
