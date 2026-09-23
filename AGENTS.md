# Dotfiles Repository

Personal Linux dotfiles managed primarily by Nix Home Manager. The repository uses a consistent config layout:

```text
tool/.config/tool/<config files>
```

`home-manager/` is the source of truth for packages, environment variables, shell configuration, and the checked-in application configurations linked into `~/.config`. See `HOME_MANAGER.md` for the longer setup and rollback guide.

## Repository Layout

These are the configuration directories currently present in the repository:

- `fresh/` — Fresh editor configuration at `fresh/.config/fresh/config.json` and `fresh/.config/fresh/init.ts`.
- `home-manager/` — Nix flake and modules: `flake.nix`, `home.nix`, and `shell.nix`; see [Flake Architecture](#flake-architecture).
- `kitty/` — Kitty terminal configuration at `kitty/.config/kitty/kitty.conf`, including color and theme files.
- `niri/` — Niri compositor configuration at `niri/.config/niri/config.kdl`, modular `dms/*.kdl` includes, scripts, icons, sounds, and wallpapers.
- `noctalia-greeter/` — Noctalia greeter declarative config (`greeter.toml`) matching the live Noctalia theme. This is a system-level greetd config (installed to root-owned `/var/lib/noctalia-greeter/greeter.toml`), not a Home Manager-link.
- `nvim/` — Neovim configuration at `nvim/.config/nvim/`, based on LazyVim.
- `rofi/` — Rofi utility-menu configuration at `rofi/.config/rofi/`, including menus, themes, and assets still used by clipboard, emoji, wallpaper, and screenshot scripts.
- `shell/` — Bash and Zsh files; see [Shell](#shell).

Root-level files include `AGENTS.md`, `HOME_MANAGER.md`, `bootstrap.sh`, and `.gitignore`. The Neovim configuration also has its own `nvim/.gitignore`.

Pi configuration is not stored in this repository. It is managed externally (for example, from `~/pi-config`) and should not be added to the repository layout unless that management arrangement changes.

## Flake Architecture

The flake is defined in `home-manager/flake.nix` and has four inputs:

- `nixpkgs` from `nixos-unstable`.
- `home-manager` from `nix-community/home-manager`, following the flake's `nixpkgs`.
- `superfile` from `yorukot/superfile`, also following the flake's `nixpkgs`.
- `vicinae` from `vicinaehq/vicinae`, providing the Home Manager module; `home.nix` uses the cached `pkgs.vicinae` package.

It provides one configuration:

- `homeConfigurations.pn` — standalone Home Manager for generic Linux systems. It imports `home.nix` and `shell.nix` with `targets.genericLinux.enable = true`.

## Home Manager and Config Links

Packages, session variables, programs, and links are declared in `home-manager/home.nix`. The `xdg.configFile` entries use `config.lib.file.mkOutOfStoreSymlink`, so they point to the live checkout rather than an immutable Nix-store copy. Editing these files in the repository does not require a rebuild for the link target to contain the change.

Home Manager currently links these existing repository paths:

- `~/.config/fresh/config.json` → `fresh/.config/fresh/config.json`
- `~/.config/fresh/init.ts` → `fresh/.config/fresh/init.ts`
- `~/.config/kitty` → `kitty/.config/kitty`
- `~/.config/niri` → `niri/.config/niri`
- `~/.config/nvim` → `nvim/.config/nvim`
- `~/.config/rofi` → `rofi/.config/rofi` (utility menus; the app launcher is Vicinae)
- `~/.zsh/.p10k.zsh` → `shell/.zsh/.p10k.zsh`
- `~/.zsh/functions.zsh` → `shell/.zsh/functions.zsh`
- `~/.zsh/secrets.zsh` → `shell/.zsh/secrets.zsh`

The `.zsh` directory remains a real directory so Home Manager can place Zsh plugins and history there. `secrets.zsh` is intentionally private and ignored by Git; create it locally on a new machine.

## Package Management

Add or remove packages in `home-manager/home.nix`, then run `home-manager switch`. The declared package groups are:

- **Development toolchains:** Node.js, OpenJDK 25, Python 3.11 with pip, Rustup, Bun, and UV.
- **CLI utilities:** ripgrep, fd, fzf, jq, gum, eza, bat, delta, glow, stylua, shellcheck, shfmt, tty-clock, pnpm, Turso CLI, and `sqld`.
- **Terminal applications:** btop, fastfetch, lazygit, `fresh-editor`, Neovim, GitHub CLI, Zellij, Vicinae, Rofi, and Superfile.
- **GUI and fonts:** KDE Okular, Iosevka, Iosevka Nerd Font, and Noto CJK fonts.

Rust toolchains are installed and selected through `rustup`; `~/.cargo/bin` is added to the session PATH. NPM globals use the writable `~/.npm-global` prefix, which is also added to PATH.

Home Manager also configures Git, fzf, zoxide, direnv, and Home Manager itself. Direnv is integrated with Zsh.

## XDG MIME Defaults

`home-manager/home.nix` enables `xdg.mimeApps` and sets Zen Browser, installed as a Flatpak, as the default handler for HTTP/HTTPS, browser, HTML, XML, and related web MIME types. KDE Okular is the default PDF handler. The existing Claude CLI URL handler is preserved.

## Shell

### Zsh

Zsh is configured declaratively by `programs.zsh` in `home-manager/shell.nix`. The configuration includes:

- Powerlevel10k, zsh-completions, and zsh-vi-mode plugins.
- fzf-tab, zsh-autosuggestions, and zsh-syntax-highlighting loaded after compinit.
- Vi-mode cursor styles and history navigation bindings.
- Shell options, history settings, aliases, keybindings, and initialization hooks.
- Powerlevel10k settings from `shell/.zsh/.p10k.zsh`.
- Custom functions from `shell/.zsh/functions.zsh`.
- Optional private API keys from `shell/.zsh/secrets.zsh`.

Common aliases include `cd` through zoxide, `cat` through bat, `ls` through eza, `vi`/`vim` through Neovim, and `lg` through lazygit. Generic Linux maintenance aliases are defined in `shell.nix`.

### Bash

The repository also contains the manually maintained Bash startup files:

- `shell/.bashrc`
- `shell/.bash_profile`

They are not part of the `programs.zsh` configuration and should be linked or installed separately if Bash is used as a login or interactive shell.

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

After bootstrap, open a new shell, recreate the ignored `shell/.zsh/secrets.zsh`, select a Rust toolchain with `rustup default stable`, and authenticate GitHub if Git credential helpers are needed.

For a standalone Home Manager update:

```bash
home-manager switch --flake ~/.config/home-manager#pn
```

Previous Home Manager generations can be rolled back with:

```bash
home-manager switch --flake ~/.config/home-manager --rollback
```
