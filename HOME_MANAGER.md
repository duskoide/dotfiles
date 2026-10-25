# Home-Manager Setup Guide

Terminal environment is managed by Nix home-manager. The flake lives in `~/dotfiles/home-manager/`
and is symlinked to `~/.config/home-manager` so there's a single repo to clone.
Every app config also lives under `~/dotfiles/home-manager/config/<app>/` and is linked into place by Home Manager.

## Architecture

Three files split responsibilities:

- **`flake.nix`** — inputs (nixpkgs, home-manager, superfile, vicinae) and flake outputs
- **`home.nix`** — global packages, session env/PATH, config symlinks, git/fzf/zoxide/direnv programs
- **`shell.nix`** — zsh and bash configuration: plugins, aliases, options, history, init hooks
- **`config/`** — raw app configs (nvim, kitty, niri, rofi, fresh, zsh extras, noctalia-greeter)

The flake targets `x86_64-linux` with `stateVersion = "24.11"` and enables `targets.genericLinux` for Fedora compatibility.

## What's Managed

### Packages (global, always in PATH)
Dev toolchains: nodejs, openjdk25, python311 (+pip), rustup, bun
CLI tools: ripgrep, fd, fzf, jq, gum, eza, bat, delta, glow, stylua, shellcheck, shfmt, tty-clock, nodePackages.pnpm, turso-cli, sqld
Terminal apps: btop, fastfetch, lazygit, fresh-editor, neovim, github-cli, zellij, Vicinae, rofi, superfile

Rust toolchains (rustc/cargo/rustfmt/clippy) come from `rustup` rather than nixpkgs, so `~/.cargo/bin` is on PATH and toolchain switching works as usual. Run `rustup default stable` once on a fresh machine.

Install/add/remove by editing `home.packages` in `home.nix` then running `home-manager switch`. Vicinae is installed and configured through its Home Manager module using the cached nixpkgs package (currently `0.22.3`); Numen is disabled because that package does not provide the backend. Its daemon starts in the user session and `Mod+D` opens the app launcher. The service receives the Mesa/EGL paths needed by the host’s graphics stack. Rofi remains for the clipboard, emoji, wallpaper, and screenshot utility menus.

### Zsh
`programs.zsh` replaces zinit entirely. Plugins load in order:
1. powerlevel10k (instant prompt configured near top)
2. zsh-completions
3. zsh-vi-mode (with custom cursor styles and arrow-key history bindings)
4. After compinit: fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting

Aliases, history settings, zstyles, and keybindings are declared directly in `shell.nix`.
Remaining custom functions live in `~/.zsh/functions.zsh` (linked from `config/zsh/`).

Secrets (`~/.zsh/secrets.zsh`) and p10k config (`~/.zsh/.p10k.zsh`) are linked from `config/zsh/` — never stored in the nix store.

### Bash
`programs.bash` generates `~/.bashrc`, `~/.bash_profile` and `~/.profile`. Bash is a fallback shell; environment comes from `hm-session-vars.sh` like zsh.

### Config Symlinks (editable in dotfiles)
These point back into `~/dotfiles/home-manager/config` via `mkOutOfStoreSymlink` — edit there, no rebuild needed:

- `~/.config/nvim` → `config/nvim` (LazyVim)
- `~/.config/kitty`, `niri`, `rofi` → `config/kitty`, `config/niri`, `config/rofi` (utility menus; Vicinae is configured declaratively)
- `~/.config/fresh/config.json`, `init.ts` → `config/fresh/`
- `~/.zsh/.p10k.zsh`, `functions.zsh`, `secrets.zsh` → `config/zsh/`

Pi config is managed externally by `~/pi-config`.

`~/.zsh` itself is a real directory (HM puts plugins in `~/.zsh/plugins`), so files are linked individually.

### File manager and theming
Thunar (host package) is the default file manager, `org.freedesktop.FileManager1` provider, and launches kitty for "Open Terminal Here". GTK uses adw-gtk3-dark, breeze-dark icons, and Noto Sans via the `gtk` module. Qt/KDE keys are set in `kdeglobals` via `qt.kde.settings`. Noctalia owns the colors (`gtk.css`, KDE `ColorScheme`) and dark/light mode. Okular is wrapped with its own Nix KDE platform theme and Breeze plugins. See AGENTS.md for the rules.

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
2. Fill in secrets: `nvim ~/dotfiles/home-manager/config/zsh/secrets.zsh`

## Rollback

```
home-manager switch --flake ~/.config/home-manager --rollback
```

Previous generations are retained automatically.

## What's Left Outside

- **Desktop/GUI binaries**: niri, sddm, pipewire, etc. stay on the host distro (dnf/flatpak); their user configs are managed here.
- **`config/noctalia-greeter/greeter.toml`**: system-level greetd config; install it to `/var/lib/noctalia-greeter/greeter.toml` as root (Home Manager cannot write there).
- **`~/.pi`**: managed by `~/pi-config`.

## File Locations

| File | Purpose |
|------|---------|
| `flake.nix` | Flake definition, inputs, module imports |
| `home.nix` | Packages, env vars, symlinks, program modules |
| `shell.nix` | Zsh/Bash plugins, aliases, options, init content |
| `config/zsh/functions.zsh` | Custom shell functions (gpush, multi-distro `ss`, etc.) |
| `config/zsh/.p10k.zsh` | Powerlevel10k theme config |
| `config/zsh/secrets.zsh` | API keys (gitignored) |
| `config/<app>/` | Raw configs for nvim, kitty, niri, rofi, fresh, noctalia-greeter |

## Local Noctalia plugins (v5)

Both **Project Tasks** and **Sleep Guard** are tracked under
`home-manager/config/noctalia-plugins/`. Home Manager links
`~/.config/noctalia-plugins` to this live source collection. Noctalia itself and
its live settings remain host-managed. To reproduce the setup on a new machine,
run this once with Noctalia running (also works before a Home Manager switch):

```bash
python3 ~/dotfiles/home-manager/config/noctalia-plugins/install.py --check
python3 ~/dotfiles/home-manager/config/noctalia-plugins/install.py
```

The installer registers the path source, enables both plugins, and adds their
bar widgets while preserving existing settings and making a backup.
Enabling Sleep Guard adds the button; actual sleep blocking remains OFF until
clicked and does not persist across reboot. Display blanking is unaffected.

Task data/backups remain in Noctalia’s state directory, outside Git. Sleep Guard
uses a transient user systemd unit; it does not edit system-wide lid policy.
See the [collection README](home-manager/config/noctalia-plugins/README.md) for
usage, tests, safety limitations, and recovery commands.
