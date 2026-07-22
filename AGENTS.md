# Dotfiles Repository

Personal dotfiles for Linux (distro-agnostic via Nix + `targets.genericLinux`), with Niri/Hyprland compositors. The dev environment and shell are managed entirely by **Nix home-manager**; desktop/GUI configs are symlinked manually.

## Repository Structure

Each tool gets a top-level directory mirroring `~/.config/`:

```
toolname/.config/toolname/<actual config files>
```

The centerpiece is `home-manager/`, which holds the flake that installs packages, configures the shell, and symlinks most app configs into place (see `HOME_MANAGER.md` for details).

Key directories:
- `home-manager/` — **Nix flake**: `flake.nix`, `home.nix` (packages, env, symlinks, programs), `shell.nix` (zsh). This is the source of truth for the dev environment.
- `shell/` — Shell config symlinked by home-manager: `.zsh/functions.zsh`, `.zsh/.p10k.zsh`, `.zsh/secrets.zsh` (gitignored). `.bashrc`/`.bash_profile` are manual.
- `niri/` — Primary compositor (KDL, split into modular `dms/` includes)
- `hypr/` — Secondary compositor (Hyprland + Hyprlock)
- `nvim/` — LazyVim-based Neovim (lazy.nvim, minimal customization)
- `opencode/` — OpenCode config (Context7 MCP, superpowers plugin, custom commands)
- `kitty/` — Terminal (Iosevka Nerd Font, Alabaster Dark theme)
- `waybar/` — Status bar (split into `modules-main.jsonc`, `modules-custom.jsonc`, `modules-groups.jsonc`)
- `rofi/` — App launcher (multiple themes in `themes/` and `menu/`)
- `yazi/` — File manager
- `helix/` — Helix editor
- `btop/` — System monitor
- `fastfetch/` — System info display
- `lazygit/` — Git TUI

## Package Management

Packages are declared in `home.packages` in `home-manager/home.nix` and installed via `home-manager switch`. There are no package-list text files — the flake is the single source of truth. Rust toolchains are managed by `rustup` (also a nix package); global npm tools use a writable `~/.npm-global` prefix.

## Shell

Zsh is configured declaratively by `programs.zsh` in `home-manager/shell.nix` (no Zinit). Plugins load in order: powerlevel10k → zsh-completions → zsh-vi-mode → (after compinit) fzf-tab, autosuggestions, syntax-highlighting. Aliases, options, history, and keybindings live in `shell.nix`.

- **Powerlevel10k** theme (nerdfont-v3, lean, transient) — config in `shell/.zsh/.p10k.zsh`
- **Vi mode** enabled with custom cursor styles
- Key aliases: `cd`→`z` (zoxide), `cat`→`bat`, `ls`→`eza`, `vi`/`vim`→`nvim`, `lg`→`lazygit`
- Custom functions in `shell/.zsh/functions.zsh` (gpush, multi-distro `ss`, etc.)
- Secrets (API keys) in `shell/.zsh/secrets.zsh` — gitignored, never in the nix store

## Desktop

- **Niri** (primary): modular KDL config, DMS integration for IPC (spotlight, clipboard, power menu, notifications, wallpaper)
- **Hyprland** (secondary): visual config in `hypr/configs.conf`
- **Waybar**: configured for Niri modules

Desktop/GUI configs (niri, hypr, rofi, waybar) are **not** managed by home-manager — they're symlinked into place manually.

## OpenCode Config

Located at `opencode/.config/opencode/`:
- Context7 MCP for library docs
- `superpowers` plugin
- Custom commands: `/review` (code review), `/workflow` (autonomous multi-agent workflow)

## Neovim

Based on **LazyVim v8** distribution. Minimal customization — only `init.lua` (sets tabstop=4). Plugins, options, keymaps, and autocmds all use LazyVim defaults. LSPs/formatters (stylua, etc.) resolve from the nix profile on PATH. Formatter: stylua (2-space, 120 col).

## Setup

Fresh machine:

```bash
bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
```

Installs Nix, enables flakes, installs home-manager, clones this repo, and runs `home-manager switch`. See `HOME_MANAGER.md` for the full architecture and rollback instructions.
