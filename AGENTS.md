# Dotfiles Repository

Personal Linux dotfiles managed entirely by Nix Home Manager. Everything lives under `home-manager/`:

```text
home-manager/
  flake.nix, home.nix, shell.nix   # Nix modules
  config/<app>/<config files>      # raw app configs, linked into place by home.nix
```

`home-manager/` is the source of truth for packages, environment variables, shell configuration, theming, default apps, and the checked-in application configurations linked into `~/.config`. See `HOME_MANAGER.md` for the longer setup and rollback guide.

## Repository Layout

- `home-manager/flake.nix`, `home.nix`, `shell.nix` — Nix flake and modules; see [Flake Architecture](#flake-architecture).
- `home-manager/config/fresh/` — Fresh editor `config.json` and `init.ts`.
- `home-manager/config/kitty/` — Kitty terminal configuration, including color and theme files.
- `home-manager/config/niri/` — Niri compositor `config.kdl`, modular `noctalia/*.kdl` includes, scripts, and wallpapers.
- `home-manager/config/noctalia-plugins/` — local Noctalia v5 plugins: Project Tasks and Sleep Guard, plus `install.py` to register/enable both and add their bar widgets. Run the installer once per machine with Noctalia running; Home Manager only links the source collection. Task data and active inhibitors stay outside Git.
- `home-manager/config/noctalia-greeter/` — Noctalia greeter config (`greeter.toml`). System-level greetd config installed as root to `/var/lib/noctalia-greeter/greeter.toml`; not linked by Home Manager.
- `home-manager/config/nvim/` — Neovim configuration based on LazyVim (has its own `.gitignore`).
- `home-manager/config/rofi/` — Rofi utility menus and themes used by clipboard, emoji, wallpaper, and screenshot scripts.
- `home-manager/config/zsh/` — `.p10k.zsh`, `functions.zsh`, and the ignored `secrets.zsh`; see [Shell](#shell).

Root-level files are `AGENTS.md`, `HOME_MANAGER.md`, `bootstrap.sh`, `nix-only.sh`, and `.gitignore`.

Pi configuration is not stored in this repository. It is managed externally (for example, from `~/pi-config`) and should not be added to the repository layout unless that management arrangement changes.

## Flake Architecture

The flake is defined in `home-manager/flake.nix` and has four inputs:

- `nixpkgs` from `nixos-unstable`.
- `home-manager` from `nix-community/home-manager`, following the flake's `nixpkgs`.
- `superfile` from `yorukot/superfile`, also following the flake's `nixpkgs`.
- `vicinae` from `vicinaehq/vicinae`, providing the Home Manager module; `home.nix` uses the cached `pkgs.vicinae` package.

It provides two configurations, both built by the same `mkHome` helper:

- `homeConfigurations.pn` — standalone Home Manager for generic Linux systems. It imports `home.nix` and `shell.nix` with `targets.genericLinux.enable = true`.
- `homeConfigurations.pn-nolinks` — the same, without linking `home-manager/config/*` into `~` (used by `nix-only.sh`).

## Home Manager and Config Links

Packages, session variables, programs, and links are declared in `home-manager/home.nix`. The `link` helper wraps `config.lib.file.mkOutOfStoreSymlink` with the `home-manager/config` prefix, so links point to the live checkout rather than an immutable Nix-store copy. Editing these files in the repository does not require a rebuild.

Home Manager links these repository paths (relative to `home-manager/config/`):

- `~/.config/fresh/config.json` → `fresh/config.json`
- `~/.config/fresh/init.ts` → `fresh/init.ts`
- `~/.config/kitty` → `kitty`
- `~/.config/noctalia-plugins` → `noctalia-plugins`
- `~/.config/niri` → `niri`
- `~/.config/nvim` → `nvim`
- `~/.config/rofi` → `rofi` (utility menus; the app launcher is Vicinae)
- `~/.zsh/.p10k.zsh`, `functions.zsh`, `secrets.zsh` → `zsh/`

When adding a new app config, put it in `home-manager/config/<app>/` and add a `link "<app>"` entry in `home.nix`.

The `.zsh` directory remains a real directory so Home Manager can place Zsh plugins and history there. `secrets.zsh` is intentionally private and ignored by Git; create it locally on a new machine.

## Package Management

Add or remove packages in `home-manager/home.nix`, then run `home-manager switch`. The declared package groups are:

- **Development toolchains:** Node.js, OpenJDK 25, Python 3.11 with pip, Rustup, Bun, and UV.
- **CLI utilities:** ripgrep, fd, fzf, jq, gum, eza, bat, delta, glow, stylua, shellcheck, shfmt, tty-clock, pnpm, Turso CLI, and `sqld`.
- **Terminal applications:** btop, fastfetch, lazygit, `fresh-editor`, Neovim, GitHub CLI, Zellij, Vicinae, Rofi, and Superfile.
- **GUI and fonts:** KDE Okular (wrapped with its own KDE platform theme and Breeze plugins), Obsidian, Iosevka, Iosevka Nerd Font, and Noto CJK fonts.

Rust toolchains are installed and selected through `rustup`; `~/.cargo/bin` is added to the session PATH. NPM globals use the writable `~/.npm-global` prefix, which is also added to PATH.

Home Manager also configures Git, fzf, zoxide, direnv, and Home Manager itself. Direnv is integrated with Zsh.

## XDG MIME Defaults

`home-manager/home.nix` enables `xdg.mimeApps` and sets Zen Browser (Fedora RPM, `zen-browser.desktop`) as the default handler for HTTP/HTTPS, browser, HTML, XML, and related web MIME types. KDE Okular is the default PDF handler and Thunar the default file manager (`inode/directory`). Claude CLI, Qoder, and Archi handlers are preserved. Desktop IDs must match an installed `.desktop` file; a missing ID makes each launcher fall back differently (gio picks Firefox, cache-based lookups pick Chromium).

## File Manager and Theming

- **Thunar** comes from the host distro (Fedora), because it needs the system gvfs, tumbler, and xfconf stack. Home Manager points `org.freedesktop.FileManager1` at Thunar through a user D-Bus service file, which overrides Caja's claim. It also makes `exo-open` launch kitty for "Open Terminal Here" (`xfce4/helpers.rc`) and writes `xdg-desktop-portal/portals.conf` to use the GTK file chooser.
- **GTK** (`gtk` module): adw-gtk3-dark, breeze-dark icons, Noto Sans 10, written to `settings.ini` and dconf. `gtk.css` and light/dark mode are owned by Noctalia's templates; do not set `gtk.gtk3.extraCss` or `gtk.gtk4.theme`.
- **Qt/KDE** (`qt.kde.settings`): `kwriteconfig6` sets icon theme, widget style, and fonts in `~/.config/kdeglobals` key by key; Noctalia sets `ColorScheme`. Nix Qt apps must be wrapped like `okularPkg` (own `QT_PLUGIN_PATH` + `QT_QPA_PLATFORMTHEME=kde`). Never put Nix Qt plugins in the global `QT_PLUGIN_PATH`: system Qt apps would load them and crash.

## Shell

### Zsh

Zsh is configured declaratively by `programs.zsh` in `home-manager/shell.nix`. The configuration includes:

- Powerlevel10k, zsh-completions, and zsh-vi-mode plugins.
- fzf-tab, zsh-autosuggestions, and zsh-syntax-highlighting loaded after compinit.
- Vi-mode cursor styles and history navigation bindings.
- Shell options, history settings, aliases, keybindings, and initialization hooks.
- Powerlevel10k settings from `home-manager/config/zsh/.p10k.zsh`.
- Custom functions from `home-manager/config/zsh/functions.zsh`.
- Optional private API keys from `home-manager/config/zsh/secrets.zsh`.

Common aliases include `cd` through zoxide, `cat` through bat, `ls` through eza, `vi`/`vim` through Neovim, and `lg` through lazygit. Generic Linux maintenance aliases are defined in `shell.nix`.

### Bash

`programs.bash` in `shell.nix` generates `~/.bashrc`, `~/.bash_profile`, and `~/.profile`. Bash is a fallback shell; its environment comes from `hm-session-vars.sh`, like Zsh.

## Setup and Bootstrap

On a fresh Linux machine with `curl` and `git` available, run:

```bash
bash <(curl -sL https://raw.githubusercontent.com/duskoide/dotfiles/main/bootstrap.sh)
```

`bootstrap.sh`:

1. Loads an existing Nix profile when present.
2. Installs single-user Nix if needed.
3. Enables the `nix-command` and `flakes` features.
4. Installs Home Manager if needed.
5. Clones or fast-forwards `~/dotfiles`.
6. Links `~/.config/home-manager` to `~/dotfiles/home-manager`.
7. Runs `home-manager switch --flake ~/.config/home-manager#pn`.

After bootstrap, open a new shell, fill in the ignored `home-manager/config/zsh/secrets.zsh`, select a Rust toolchain with `rustup default stable`, and authenticate GitHub if Git credential helpers are needed.

For a standalone Home Manager update:

```bash
home-manager switch --flake ~/.config/home-manager#pn
```

Previous Home Manager generations can be rolled back with:

```bash
home-manager switch --flake ~/.config/home-manager --rollback
```
