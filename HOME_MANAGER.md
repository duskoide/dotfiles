# Home-Manager Setup Guide

Terminal environment is managed by Nix home-manager. The flake lives in `~/dotfiles/home-manager/`
and is symlinked to `~/.config/home-manager` so there's a single repo to clone.
Desktop/configs live in `~/dotfiles` and are symlinked into place.

## Architecture

Three files split responsibilities:

- **`flake.nix`** — inputs (nixpkgs, home-manager, herdr) and flake outputs
- **`home.nix`** — global packages, session env/PATH, config symlinks, git/fzf/zoxide/direnv programs
- **`shell.nix`** — zsh configuration: plugins, aliases, options, history, init hooks

The flake targets `x86_64-linux` with `stateVersion = "24.11"` and enables `targets.genericLinux` for Fedora compatibility.

## What's Managed

### Packages (global, always in PATH)
Dev toolchains: nodejs, openjdk25, python311 (+pip), rustup, bun
CLI tools: ripgrep, fd, fzf, jq, gum, eza, bat, delta, glow, stylua, shellcheck, shfmt, tty-clock, nodePackages.pnpm, turso-cli, sqld
Terminal apps: btop, fastfetch, lazygit, helix, yazi, neovim, github-cli, zellij, rofi, herdr

Rust toolchains (rustc/cargo/rustfmt/clippy) come from `rustup` rather than nixpkgs, so `~/.cargo/bin` is on PATH and toolchain switching works as usual. Run `rustup default stable` once on a fresh machine.

Install/add/remove by editing `home.packages` in `home.nix` then running `home-manager switch`.

### Zsh
`programs.zsh` replaces zinit entirely. Plugins load in order:
1. powerlevel10k (instant prompt configured near top)
2. zsh-completions
3. zsh-vi-mode (with custom cursor styles and arrow-key history bindings)
4. After compinit: fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting

Aliases, history settings, zstyles, and keybindings are declared directly in `shell.nix`.
Remaining custom functions live in `~/.zsh/functions.zsh` (symlinked from dotfiles).

Secrets (`~/.zsh/secrets.zsh`) and p10k config (`~/.zsh/.p10k.zsh`) are symlinked from the dotfiles repo — never stored in the nix store.

### Config Symlinks (editable in dotfiles)
These point back into `~/dotfiles` via `mkOutOfStoreSymlink` — edit there, no rebuild needed:

- `~/.config/nvim` → LazyVim
- `~/.config/helix`, `yazi`, `btop`, `fastfetch`, `lazygit`, `kitty`, `opencode`
- `~/.zsh/.p10k.zsh`, `functions.zsh`, `secrets.zsh`
- `~/.pi/web-search.json`, `~/.pi/agent/settings.json`, `APPEND_SYSTEM.md`, `alibaba-config.json`, `agents/*.md` (pi coding agent; `~/.pi/agent` stays a real dir for runtime state, `auth.json` gitignored)
- `~/.config/herdr/config.toml` (herdr; `~/.config/herdr` stays a real dir for plugins/session/logs, all gitignored)

`~/.zsh` itself is a real directory (HM puts plugins in `~/.zsh/plugins`), so files are linked individually.

## Direnv Integration

`direnv` is enabled with zsh hook integration. Global tools (node, bun, npm) remain available everywhere via the nix profile.

Inside a project directory, add `.envrc` to layer local tools:

```
direnv allow
PATH_add ./node_modules/.bin
```

When you leave the directory, direnv unloads automatically. For per-project toolchains, use a nix dev shell (`nix develop` with a `flake.nix`) or `direnv` `use flake` instead of a separate version manager.

## Git Configuration

Managed via `programs.git` — writes to `~/.config/git/config` with your user info and GitHub/Gist credential helpers via `gh`.

## New Machine Setup

One command on a fresh machine:

```bash
bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
```

This installs Nix, enables flakes, installs home-manager, clones this repo,
symlinks `~/.config/home-manager` → `~/dotfiles/home-manager`, and runs `home-manager switch`.

After it finishes:
1. Open a new shell (or `source ~/.zshrc`)
2. Recreate secrets: `nvim ~/dotfiles/shell/.zsh/secrets.zsh`
3. Symlink any desktop configs not covered by HM (niri, hypr, rofi, waybar) if needed

## Rollback

```
home-manager switch --flake ~/.config/home-manager --rollback
```

Previous generations are retained automatically.

## What's Left Outside

- **Desktop/GUI**: niri, hyprland, waybar, rofi, sddm, pipewire, etc. stay on the host distro (dnf/flatpak). Config files for these are still symlinked manually from dotfiles.
- **`~/.pi`**: Live runtime state (not symlinked — the repo copy is only a partial backup).
- **Bash files**: `~/.bashrc` and `~/.bash_profile` remain manual symlinks (zsh is the primary shell).

## File Locations

| File | Purpose |
|------|---------|
| `flake.nix` | Flake definition, inputs, module imports |
| `home.nix` | Packages, env vars, symlinks, program modules |
| `shell.nix` | Zsh plugins, aliases, options, init content |
| `dotfiles/shell/.zsh/functions.zsh` | Custom shell functions (gpush, multi-distro `ss`, etc.) |
| `dotfiles/shell/.zsh/.p10k.zsh` | Powerlevel10k theme config |
| `dotfiles/shell/.zsh/secrets.zsh` | API keys (gitignored) |
