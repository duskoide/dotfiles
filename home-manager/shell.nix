{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;

    setOptions = [
      "autocd"
      "correct"
      "interactivecomments"
      "magicequalsubst"
      "nonomatch"
      "notify"
      "numericglobsort"
      "promptsubst"
    ];

    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.zsh/.zsh_history";
      append = true;
      share = true;
      ignoreSpace = true;
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
    };

    shellAliases = {
      # eza
      ls = "eza -T --level=1 --color=always --icons=always";
      la = "eza -a --icons=always";
      ll = "eza -l -a --icons=always --no-time";
      lst = "eza -T --level=2 --color=always --icons=always";
      lsf = "eza -f -a --color=always --icons=always";
      lstd = "eza -D -T --level=2 --color=always --icons=always";
      tree = "eza -T --level=3 --color=always --icons=always";

      cat = "bat";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";

      # navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      root = "cd /";
      cd = "z";

      # misc
      src = "source ~/.zshrc";
      clr = "clear";
      cls = "clear";
      clar = "clear";
      c = "clear";
      q = "exit";
      sshloq = "ssh pn@ssh.duskoide.org";
      dockerreset = "docker compose down -v && docker compose up -d && sleep 2 && docker compose ps";
      du = "du -sh";
      mkdir = "mkdir -pv";
      exe = "chmod +x";
      clock = "tty-clock -c -t -D -s";
      ff = "clr && fastfetch";
      sys = "btop";

      # grub (multi-distro)
      grubup = "sudo update-grub";
      susegrub = "sudo grub2-mkconfig -o /boot/grub2/grub.cfg";
      fedbup = "sudo grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg";
      dup = "sudo zypper dup -y";

      # fzf
      find = ''nvim $(fzf --preview="bat --color=always {}")'';

      # editors
      nv = "nvim";
      nvm = "nvim .";
      snv = "sudo -E nvim -d";
      vi = "nvim";
      vim = "nvim";
      svi = "sudo nvim";
      vis = ''nvim "+set si"'';

      # git
      add = "git add .";
      clone = "git clone";
      cloned = "git clone --depth=1";
      branch = "git branch -M main";
      commit = "git commit -m";
      push = "git push";
      pushm = "git push -u origin main";
      pusho = "git push origin";
      pull = "git pull";
      status = "git status";
      lg = "lazygit";

      # network
      iplocal = "ip -br -c a";
      ipexternal = "curl -s ifconfig.me && echo";

      # etc
      homesw = "home-manager switch --flake /home/pn/.config/home-manager#pn";
      homeedit = "nvim ~/.config/home-manager/home.nix";
      shelledit = "nvim ~/.config/home-manager/shell.nix";
    };

    plugins = [
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
      {
        name = "zsh-completions";
        src = pkgs.zsh-completions;
        file = "share/zsh-completions/zsh-completions.plugin.zsh";
      }
      {
        name = "zsh-vi-mode";
        src = pkgs.zsh-vi-mode;
        file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # Runs before plugins are sourced.
      (lib.mkBefore ''
        # p10k instant prompt — must stay near the top
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi

        # zsh-vi-mode cursor styles (applied during plugin load via zvm_config)
        function zvm_config() {
          ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
          ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
          ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
        }

        # History navigation that leaves the cursor at the END of the line.
        # zsh-vi-mode rebinds the arrow keys, so we apply these via its
        # after-init hook to make sure our binding wins.
        function hist-backward-end() {
          zle up-history
          zle end-of-line
        }
        function hist-forward-end() {
          zle down-history
          zle end-of-line
        }
        zle -N hist-backward-end
        zle -N hist-forward-end
        zvm_after_init_commands+=(
          "bindkey '^[[A' hist-backward-end"
          "bindkey '^[[B' hist-forward-end"
        )
      '')

      # Runs after compinit.
      (''
        # Plugins that must load after compinit, in this order
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
        zstyle ':completion:*:*:docker:*' option-stacking yes
        zstyle ':completion:*:*:docker-*:*' option-stacking yes

        bindkey "^[[A" hist-backward-end
        bindkey "^[[B" hist-forward-end

        [[ -f ~/.zsh/.p10k.zsh ]] && source ~/.zsh/.p10k.zsh
        source ~/.zsh/functions.zsh
        # API keys live in a private, non-committed file (never in the nix store)
        [[ -f ~/.zsh/secrets.zsh ]] && source ~/.zsh/secrets.zsh

        [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
      '')
    ];
  };
}
