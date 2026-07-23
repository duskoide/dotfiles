{ config, pkgs, lib, herdr, ... }:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  # Symlink that points at the live dotfiles checkout instead of the nix
  # store, so files stay editable without a rebuild.
  link = config.lib.file.mkOutOfStoreSymlink;
in {
  home.username = "pn";
  home.homeDirectory = "/home/pn";
  home.stateVersion = "24.11";

  # Non-NixOS (Fedora) integration: locales, etc.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    zsh
    kitty.terminfo

    # dev toolchains
    nodejs
    openjdk25
    python311
    python311Packages.pip
    rustup
    bun

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
    helix
    yazi
    neovim
    github-cli
    zellij
    rofi
    herdr.packages.${pkgs.system}.default

    # GUI apps
    kdePackages.okular

    # Fonts
    iosevka-bin
    nerd-fonts.iosevka
    noto-fonts-cjk-serif
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    TERMINAL = "kitty";
    # nix zsh needs to find xterm-kitty terminfo (kitty.terminfo pkg)
    TERMINFO_DIRS = "${config.home.homeDirectory}/.nix-profile/share/terminfo:/usr/share/terminfo";
    BROWSER = "flatpak run app.zen_browser.zen";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    PAGER = "bat";
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    FZF_DEFAULT_OPTS = "--info=inline-right --ansi --layout=reverse --border=rounded "
      + "--color=border:#27a1b9 --color=fg:#c0caf5 --color=gutter:#16161e "
      + "--color=header:#ff9e64 --color=hl+:#2ac3de --color=hl:#2ac3de "
      + "--color=info:#545c7e --color=marker:#ff007c --color=pointer:#ff007c "
      + "--color=prompt:#2ac3de --color=query:#c0caf5:regular "
      + "--color=scrollbar:#27a1b9 --color=separator:#ff9e64 --color=spinner:#ff007c";
  };

  # nix store is immutable; give npm a writable global prefix + PATH
  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.cargo/bin"
  ];

  # Dotfiles repo configs, linked into place by home-manager.
  # Edit in ~/dotfiles, no rebuild needed.
  # ~/.zsh itself stays a real directory (HM puts zsh plugins in ~/.zsh/plugins),
  # so the repo files are linked individually. secrets.zsh stays out of the
  # nix store this way, and .zsh_history lives in the real dir.
  home.file.".zsh/.p10k.zsh".source = link "${dotfiles}/shell/.zsh/.p10k.zsh";
  home.file.".zsh/functions.zsh".source = link "${dotfiles}/shell/.zsh/functions.zsh";
  home.file.".zsh/secrets.zsh".source = link "${dotfiles}/shell/.zsh/secrets.zsh";

  # pi (coding agent). ~/.pi/agent stays a real dir for runtime state
  # (sessions/, memory/, npm/, caches, auth.json); only static config is
  # linked from the repo. auth.json is never committed — re-auth per machine.
  home.file.".pi/web-search.json".source = link "${dotfiles}/pi/.pi/web-search.json";
  home.file.".pi/agent/settings.json".source = link "${dotfiles}/pi/.pi/agent/settings.json";
  home.file.".pi/agent/APPEND_SYSTEM.md".source = link "${dotfiles}/pi/.pi/agent/APPEND_SYSTEM.md";
  home.file.".pi/agent/alibaba-config.json".source = link "${dotfiles}/pi/.pi/agent/alibaba-config.json";
  home.file.".pi/agent/agents/check.md".source = link "${dotfiles}/pi/.pi/agent/agents/check.md";
  home.file.".pi/agent/agents/explore.md".source = link "${dotfiles}/pi/.pi/agent/agents/explore.md";
  home.file.".pi/agent/agents/make.md".source = link "${dotfiles}/pi/.pi/agent/agents/make.md";
  home.file.".pi/agent/agents/orchestrator.md".source = link "${dotfiles}/pi/.pi/agent/agents/orchestrator.md";
  home.file.".pi/agent/agents/simplify.md".source = link "${dotfiles}/pi/.pi/agent/agents/simplify.md";
  home.file.".pi/agent/agents/test.md".source = link "${dotfiles}/pi/.pi/agent/agents/test.md";

  xdg.configFile = {
    nvim.source = link "${dotfiles}/nvim/.config/nvim";
    helix.source = link "${dotfiles}/helix/.config/helix";
    yazi.source = link "${dotfiles}/yazi/.config/yazi";
    btop.source = link "${dotfiles}/btop/.config/btop";
    fastfetch.source = link "${dotfiles}/fastfetch/.config/fastfetch";
    lazygit.source = link "${dotfiles}/lazygit/.config/lazygit";
    kitty.source = link "${dotfiles}/kitty/.config/kitty";
    opencode.source = link "${dotfiles}/opencode/.config/opencode";
    # herdr: link only config.toml; ~/.config/herdr stays a real dir for
    # runtime state (plugins/, plugins.json, session.json, logs).
    "herdr/config.toml".source = link "${dotfiles}/herdr/.config/herdr/config.toml";
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

  programs.home-manager.enable = true;

}
