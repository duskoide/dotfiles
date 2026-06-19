# Dotfiles Repository

Personal dotfiles for Arch Linux with Niri/Hyprland compositors.

## Repository Structure

Each tool gets a top-level directory mirroring `~/.config/`:

```
toolname/.config/toolname/<actual config files>
```

This is **not** stow, yadm, or chezmoi format. There is no symlink automation — configs are manually managed.

Key directories:
- `shell/` — Zsh config (`.zshrc`, `.zsh/alias.zsh`, `.zsh/functions.zsh`, `.p10k.zsh`)
- `niri/` — Primary compositor (KDL, split into modular `dms/` includes)
- `hypr/` — Secondary compositor (Hyprland + Hyprlock)
- `nvim/` — LazyVim-based Neovim (lazy.nvim, minimal customization)
- `opencode/` — OpenCode config (Context7 MCP, superpowers plugin, custom commands)
- `kitty/` — Terminal (Iosevka Nerd Font, Alabaster Dark theme)
- `waybar/` — Status bar (split into `modules-main.jsonc`, `modules-custom.jsonc`, `modules-groups.jsonc`)
- `rofi/` — App launcher (multiple themes in `themes/` and `menu/`)
- `mise/` — Tool version manager config
- `yazi/` — File manager
- `helix/` — Helix editor
- `btop/` — System monitor
- `fastfetch/` — System info display
- `lazygit/` — Git TUI

## Package Lists

`main_packages.txt` (202 packages) and `aur_packages.txt` (27 packages) are manual documentation of installed Arch packages. They are NOT install scripts.

## Shell

- **Zsh** with Zinit plugin manager
- **Powerlevel10k** theme (nerdfont-v3, lean, transient)
- **Vi mode** enabled (`bindkey -v`)
- Key aliases: `cd`→`z` (zoxide), `cat`→`bat`, `ls`→`eza`, `vi`/`vim`→`nvim`, `lg`→`lazygit`
- Multi-distro functions in `shell/.zsh/functions.zsh` (detects pacman/dnf/zypper/apt)

## Desktop

- **Niri** (primary): modular KDL config, DMS integration for IPC (spotlight, clipboard, power menu, notifications, wallpaper)
- **Hyprland** (secondary): visual config in `hypr/configs.conf`
- **Waybar**: configured for Niri modules

## OpenCode Config

Located at `opencode/.config/opencode/`:
- Context7 MCP for library docs
- `superpowers` plugin
- Custom commands: `/review` (code review), `/workflow` (autonomous multi-agent workflow)
- Backed-up agent definitions in `agents.bak/` (now provided by superpowers plugin)

## Mise Tools

`mise/.config/mise/config.toml` manages: Neovim, Kitty, ripgrep, fd, fzf, stylua, shellcheck, shfmt, Node.js 20, Python 3.11, Rust.

## Neovim

Based on **LazyVim v8** distribution. Minimal customization — only `init.lua` (prepends mise shims, sets tabstop=4). Plugins, options, keymaps, and autocmds all use LazyVim defaults. Formatter: stylua (2-space, 120 col).
