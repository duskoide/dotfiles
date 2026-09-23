{ config, pkgs, superfile, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  # Symlink that points at the live dotfiles checkout instead of the nix
  # store, so files stay editable without a rebuild.
  link = config.lib.file.mkOutOfStoreSymlink;

  # GUI OpenGL/EGL apps need Nixpkgs Mesa/EGL vendor ICD configuration.
  kittyPkg = pkgs.symlinkJoin {
    name = "kitty";
    paths = [ pkgs.kitty ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kitty \
        --set __EGL_VENDOR_LIBRARY_FILENAMES "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json" \
        --set LIBGL_DRIVERS_PATH "${pkgs.mesa}/lib/dri"
    '';
  };
in {
  home.username = "pn";
  home.homeDirectory = "/home/pn";
  home.stateVersion = "24.11";

  # Allow unfree packages (e.g. Obsidian). Set a predicate instead if you'd
  # rather whitelist specific packages: allowUnfreePredicate = pkg: ...
  nixpkgs.config.allowUnfree = true;

  # Generic Linux integration: locales, etc.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    kittyPkg

    # dev toolchains
    nodejs_24
    go
    openjdk25
    python311
    python311Packages.pip
    rustup
    bun
    uv
    # native build toolchain: node-gyp needs make + g++ to compile
    # native npm modules (e.g. node-pty) on Linux
    gnumake
    gcc13

    # cli utilities
    ripgrep
    fd
    fzf
    jq
    gum
    eza
    bat
    delta
    glow
    stylua
    shellcheck
    shfmt
    tty-clock
    pnpm
    turso-cli
    sqld

    # terminal apps
    btop
    fastfetch
    lazygit
    fresh-editor
    neovim
    github-cli
    # Rofi remains available for clipboard, emoji, wallpaper, and screenshot menus.
    rofi
    tectonic
    termusic
    superfile.packages.${pkgs.system}.default

    # GUI apps
    kdePackages.okular
    obsidian

    # Fonts
    iosevka-bin
    nerd-fonts.iosevka
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  home.sessionVariables = {
    LIBVIRT_DEFAULT_URI = "qemu:///system";
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    TERMINAL = "kitty";
    # nix zsh needs to find xterm-kitty terminfo (kitty.terminfo pkg)
    TERMINFO_DIRS = "${config.home.homeDirectory}/.nix-profile/share/terminfo:/usr/share/terminfo";
    BROWSER = "flatpak run app.zen_browser.zen";
    # plannotator pi extension: BROWSER above is multi-word (flatpak run ...) and breaks spawn()
    PLANNOTATOR_BROWSER = "xdg-open";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    FZF_DEFAULT_OPTS = "--info=inline-right --ansi --layout=reverse --border=rounded "
      + "--color=border:#27a1b9 --color=fg:#c0caf5 --color=gutter:#16161e "
      + "--color=header:#ff9e64 --color=hl+:#2ac3de --color=hl:#2ac3de "
      + "--color=info:#545c7e --color=marker:#ff007c --color=pointer:#ff007c "
      + "--color=prompt:#2ac3de --color=query:#c0caf5:regular "
      + "--color=scrollbar:#27a1b9 --color=separator:#ff9e64 --color=spinner:#ff007c";
    SEARXNG_URL = "http://100.64.0.0:8888";
    GOPATH = "$HOME/go";
  };

  # nix store is immutable; give npm a writable global prefix + PATH
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/go/bin"
  ];

  # Dotfiles repo configs, linked into place by home-manager.
  # Edit in ~/dotfiles, no rebuild needed.
  # ~/.zsh itself stays a real directory (HM puts zsh plugins in ~/.zsh/plugins),
  # so the repo files are linked individually. secrets.zsh stays out of the
  # nix store this way, and .zsh_history lives in the real dir.
  home.file.".zsh/.p10k.zsh".source = link "${dotfiles}/shell/.zsh/.p10k.zsh";
  home.file.".zsh/functions.zsh".source = link "${dotfiles}/shell/.zsh/functions.zsh";
  home.file.".zsh/secrets.zsh".source = link "${dotfiles}/shell/.zsh/secrets.zsh";

  # pi (coding agent) config is managed by ~/pi-config (install.sh links it).

  xdg.configFile = {
    nvim.source = link "${dotfiles}/nvim/.config/nvim";
    kitty.source = link "${dotfiles}/kitty/.config/kitty";
    "fresh/config.json".source = link "${dotfiles}/fresh/.config/fresh/config.json";
    "fresh/init.ts".source = link "${dotfiles}/fresh/.config/fresh/init.ts";
    # Manage the complete Niri configuration directory from the repository.
    niri.source = link "${dotfiles}/niri/.config/niri";
    rofi.source = link "${dotfiles}/rofi/.config/rofi";
  };

  # Default web browser = Zen (flatpak). Covers every scheme/MIME type apps
  # use to launch a browser, so links stop opening in Chromium.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "app.zen_browser.zen.desktop";
      "x-scheme-handler/https" = "app.zen_browser.zen.desktop";
      "x-scheme-handler/chrome" = "app.zen_browser.zen.desktop";
      "x-scheme-handler/about" = "app.zen_browser.zen.desktop";
      "x-scheme-handler/unknown" = "app.zen_browser.zen.desktop";
      "text/html" = "app.zen_browser.zen.desktop";
      "text/xml" = "app.zen_browser.zen.desktop";
      "application/xhtml+xml" = "app.zen_browser.zen.desktop";
      "application/xml" = "app.zen_browser.zen.desktop";
      "application/vnd.mozilla.xul+xml" = "app.zen_browser.zen.desktop";
      "application/x-extension-htm" = "app.zen_browser.zen.desktop";
      "application/x-extension-html" = "app.zen_browser.zen.desktop";
      "application/x-extension-shtml" = "app.zen_browser.zen.desktop";
      "application/x-extension-xht" = "app.zen_browser.zen.desktop";
      "application/x-extension-xhtml" = "app.zen_browser.zen.desktop";
      "application/pdf" = "org.kde.okular.desktop";
      # preserve existing handler
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Rafi Putra Nugraha";
      user.email = "rafipeen@gmail.com";
      credential."https://github.com".helper = [ "" "!gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!gh auth git-credential" ];
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };

  # Vicinae provides the app launcher and runs its daemon in the user session.
  programs.vicinae = {
    enable = true;
    # Use the cached nixpkgs build instead of compiling the upstream flake locally.
    package = pkgs.vicinae;
    # The pinned nixpkgs package predates the Numen backend.
    enableNumen = false;
    settings.font.normal.family = "Iosevka";
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
        # Match the Mesa/EGL workaround used by the Kitty wrapper.
        __EGL_VENDOR_LIBRARY_FILENAMES =
          "${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json";
        LIBGL_DRIVERS_PATH = "${pkgs.mesa}/lib/dri";
      };
    };
  };

  # Japanese input via Fcitx5 + mozc.
  # niri's config (~/dotfiles/niri/.config/niri/config.kdl) already spawns fcitx5
  # (`spawn-at-startup "fcitx5" "-d"`) and sets GTK/QT/XMODIFIERS/SDL_IM_MODULE, so
  # fcitx5 is single-instance and any systemd service + the spawn coexist fine.
  # Toggle between the Latin (keyboard-us) and Japanese (mozc) input methods with
  # Ctrl+Space inside the default group.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
      settings.inputMethod = {
        GroupOrder."0" = "Default";
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "mozc";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "mozc";
      };
    };
  };

  programs.home-manager.enable = true;

}
