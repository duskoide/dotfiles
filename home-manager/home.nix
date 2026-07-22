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
    # dev toolchains
    nodejs
    openjdk25
    python311
    rustc
    cargo
    rustfmt
    clippy
    bun
    python314Packages.pip

    # cli utilities
    ripgrep
    fd
    fzf
    jq
    gum
    eza
    bat
    stylua
    shellcheck
    shfmt
    tty-clock

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
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SUDO_EDITOR = "nvim";
    TERMINAL = "kitty";
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

  xdg.configFile = {
    nvim.source = link "${dotfiles}/nvim/.config/nvim";
    helix.source = link "${dotfiles}/helix/.config/helix";
    yazi.source = link "${dotfiles}/yazi/.config/yazi";
    btop.source = link "${dotfiles}/btop/.config/btop";
    fastfetch.source = link "${dotfiles}/fastfetch/.config/fastfetch";
    lazygit.source = link "${dotfiles}/lazygit/.config/lazygit";
    kitty.source = link "${dotfiles}/kitty/.config/kitty";
    opencode.source = link "${dotfiles}/opencode/.config/opencode";
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
