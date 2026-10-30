{ config, lib, pkgs, superfile, linkDotfiles ? true, ... }:

let
  # All app configs live under ~/dotfiles/home-manager/config/<app>.
  cfg = "${config.home.homeDirectory}/dotfiles/home-manager/config";
  # Symlink that points at the live dotfiles checkout instead of the nix
  # store, so files stay editable without a rebuild.
  link = path: config.lib.file.mkOutOfStoreSymlink "${cfg}/${path}";

  # markitdown -> pdfplumber -> pandas-stubs. In the pinned nixpkgs (e7a3ca8,
  # ~Jul 2026) that stubs derivation cannot build: it runs pandas' own test
  # suite through doInstallCheck (23 failures against numpy 2.5) and demands
  # an `import pandas` check although pandas is not in its environment.
  # pandas-stubs is a check-only input of pdfplumber and is absent from
  # markitdown's runtime dependencies, so skipping those checks changes
  # nothing at runtime. Drop this when the nixpkgs input is bumped.
  pyPkgs = pkgs.python3Packages.overrideScope (_final: prev:
    lib.optionalAttrs (prev ? pandas-stubs) {
      pandas-stubs = prev.pandas-stubs.overridePythonAttrs (_: {
        doCheck = false;
        doInstallCheck = false;
        pythonImportsCheck = [ ];
      });
    });

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

  # Nix Okular cannot load Fedora's Qt plugins (different Qt build), so give it
  # its own KDE platform theme + Breeze style. It then follows ~/.config/kdeglobals
  # (colors from Noctalia, icons/style from qt.kde.settings below). Kept out of
  # the global QT_PLUGIN_PATH so system Qt apps never load Nix plugins.
  okularPkg = pkgs.symlinkJoin {
    name = "okular";
    paths = [ pkgs.kdePackages.okular ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/okular \
        --prefix QT_PLUGIN_PATH : "${lib.makeSearchPath pkgs.kdePackages.qtbase.qtPluginPrefix [
          pkgs.kdePackages.plasma-integration
          pkgs.kdePackages.breeze
        ]}" \
        --set QT_QPA_PLATFORMTHEME kde
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
    pyPkgs.markitdown

    # Rofi remains available for clipboard, emoji, wallpaper, and screenshot menus.
    rofi
    tectonic
    termusic
    superfile.packages.${pkgs.system}.default

    # GUI apps (Thunar itself comes from the host distro: it needs the
    # system gvfs/tumbler/xfconf stack for trash, mounts, and thumbnails)
    okularPkg
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
    # Zen is the Fedora RPM (zen-browser), not the Flatpak.
    BROWSER = "zen-browser";
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
    "${config.home.homeDirectory}/.tokenharbor/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/go/bin"
  ];

  # Repo configs (home-manager/config/*), linked into place by home-manager.
  # Edit in ~/dotfiles/home-manager/config, no rebuild needed.
  # ~/.zsh itself stays a real directory (HM puts zsh plugins in ~/.zsh/plugins),
  # so the repo files are linked individually. secrets.zsh stays out of the
  # nix store this way, and .zsh_history lives in the real dir.
  # Skipped for the `pn-nolinks` flake output (linkDotfiles = false).
  home.file = lib.mkIf linkDotfiles {
    ".zsh/.p10k.zsh".source = link "zsh/.p10k.zsh";
    ".zsh/functions.zsh".source = link "zsh/functions.zsh";
    ".zsh/secrets.zsh".source = link "zsh/secrets.zsh";
  };

  # pi (coding agent) config is managed by ~/pi-config (install.sh links it).

  xdg.configFile = lib.mkMerge [ (lib.mkIf linkDotfiles {
    nvim.source = link "nvim";
    kitty.source = link "kitty";
    "fresh/config.json".source = link "fresh/config.json";
    "fresh/init.ts".source = link "fresh/init.ts";
    # Manage the complete Niri configuration directory from the repository.
    niri.source = link "niri";
    rofi.source = link "rofi";
    "noctalia-plugins".source = link "noctalia-plugins";
  }) {
    # Thunar "Open Terminal Here" (exo-open) -> kitty; helper defined below.
    "xfce4/helpers.rc".text = ''
      TerminalEmulator=kitty
    '';
    # Portal file pickers use the GTK dialog, matching Thunar.
    "xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=gnome
      org.freedesktop.impl.portal.FileChooser=gtk
    '';
  } ];

  # Default web browser = Zen (Fedora RPM, zen-browser.desktop). The desktop ID
  # must exist, or every launcher silently falls back on its own (gio -> Firefox,
  # mimeinfo.cache users -> Chromium). Covers every scheme/MIME type apps
  # use to launch a browser, so links stop opening in Chromium.
  xdg.mimeApps = let zen = "zen-browser.desktop"; in {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = zen;
      "x-scheme-handler/https" = zen;
      "x-scheme-handler/chrome" = zen;
      "x-scheme-handler/about" = zen;
      "x-scheme-handler/unknown" = zen;
      "text/html" = zen;
      "text/xml" = zen;
      "application/xhtml+xml" = zen;
      "application/xml" = zen;
      "application/vnd.mozilla.xul+xml" = zen;
      "application/x-extension-htm" = zen;
      "application/x-extension-html" = zen;
      "application/x-extension-shtml" = zen;
      "application/x-extension-xht" = zen;
      "application/x-extension-xhtml" = zen;
      "application/pdf" = "org.kde.okular.desktop";
      "inode/directory" = "thunar.desktop";
      # preserve existing handler
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
      "x-scheme-handler/qoder" = "qoder.desktop";
      "x-scheme-handler/qoder-app" = "qoder.desktop";
      "application/x-archimate" = "archi.desktop";
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

  # ---- File manager: Thunar -------------------------------------------------
  # Both Thunar and Caja claim org.freedesktop.FileManager1 ("Show in folder"
  # from browsers etc.). A user-level service file wins over /usr/share.
  xdg.dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.FileManager1
    Exec=/usr/bin/Thunar --gapplication-service
    SystemdService=thunar.service
  '';

  # "Open Terminal Here" (Thunar custom action -> exo-open) launches kitty;
  # helpers.rc is set in xdg.configFile above.
  xdg.dataFile."xfce4/helpers/kitty.desktop".text = ''
    [Desktop Entry]
    NoDisplay=true
    Version=1.0
    Type=X-XFCE-Helper
    X-XFCE-Category=TerminalEmulator
    X-XFCE-Commands=kitty
    X-XFCE-CommandsWithParameter=kitty -- "%s"
    Icon=kitty
    Name=kitty
  '';

  # ---- Toolkit theming ------------------------------------------------------
  # Noctalia owns colors and light/dark mode: it writes gtk-{3,4}.0/gtk.css
  # (imports noctalia.css), flips adw-gtk3/adw-gtk3-dark and the color-scheme
  # key, and applies its KDE color scheme to kdeglobals. Home Manager only sets
  # the rules underneath: theme family, icons, font, widget style.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "breeze-dark";
      package = pkgs.kdePackages.breeze-icons;
    };
    font = {
      name = "Noto Sans";
      size = 10;
    };
    # Leave gtk-4.0/gtk.css to Noctalia (libadwaita ignores gtk-theme-name).
    gtk4.theme = null;
  };

  # Qt/KDE apps read these from kdeglobals. kwriteconfig6 edits keys in place,
  # so Noctalia's ColorScheme and app-written state are left alone.
  qt.kde.settings.kdeglobals = {
    Icons.Theme = "breeze-dark";
    KDE.widgetStyle = "Breeze";
    General = {
      font = "Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      fixed = "Iosevka,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
    };
  };

  # Japanese input via Fcitx5 + mozc.
  # niri's config (home-manager/config/niri/config.kdl) already spawns fcitx5
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
