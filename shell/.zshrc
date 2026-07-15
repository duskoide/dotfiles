# p10k instant prompt must be sourced early
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

############################################
# Zinit plugin manager
############################################
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# zsh-vi-mode cursor styles (applied during plugin load via zvm_config)
function zvm_config() {
  ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
  ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
  ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
}

# History search that leaves the cursor at the END of the line (not the start).
# zsh-vi-mode rebinds the arrow keys, so we apply these via its after-init hook
# to make sure our binding wins over the plugin's default vi-style binding.
function hist-backward-end() {
  zle history-beginning-search-backward
  zle end-of-line
}
function hist-forward-end() {
  zle history-beginning-search-forward
  zle end-of-line
}
zle -N hist-backward-end
zle -N hist-forward-end
zvm_after_init_commands+=(
  "bindkey '^[[A' hist-backward-end"
  "bindkey '^[[B' hist-forward-end"
)
zinit light jeffreytse/zsh-vi-mode

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

autoload -Uz compinit && compinit
zinit cdreplay -q

[[ -f ~/.zsh/.p10k.zsh ]] && source ~/.zsh/.p10k.zsh

#######################################################
# Options
#######################################################
setopt autocd correct interactivecomments magicequalsubst
setopt nonomatch notify numericglobsort promptsubst

setopt appendhistory sharehistory
setopt hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_find_no_dups

#######################################################
# Environment
#######################################################
export EDITOR="nvim"
export VISUAL="nvim"
export SUDO_EDITOR=nvim
export FCEDIT=nvim
export HISTSIZE=10000
export HISTFILE=~/.zsh/.zsh_history
export SAVEHIST=$HISTSIZE
export HISTDUP=erase
# API keys are loaded from a private, non-committed file (chmod 600)
[[ -f ~/.zsh/secrets.zsh ]] && source ~/.zsh/secrets.zsh

if [[ -x "$(command -v bat)" ]]; then
	export MANPAGER="sh -c 'col -bx | bat -l man -p'"
	export PAGER=bat
fi

if [[ -x "$(command -v fzf)" ]]; then
	export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS \
	  --info=inline-right --ansi --layout=reverse --border=rounded \
	  --color=border:#27a1b9 --color=fg:#c0caf5 --color=gutter:#16161e \
	  --color=header:#ff9e64 --color=hl+:#2ac3de --color=hl:#2ac3de \
	  --color=info:#545c7e --color=marker:#ff007c --color=pointer:#ff007c \
	  --color=prompt:#2ac3de --color=query:#c0caf5:regular \
	  --color=scrollbar:#27a1b9 --color=separator:#ff9e64 --color=spinner:#ff007c \
	"
fi

#######################################################
# Keybindings
#######################################################
# Arrow keys: recall previous/next history entry, cursor jumps to end of line.
# (The effective binding for zsh-vi-mode is applied via zvm_after_init_commands
#  in the plugin-load block above; these lines mirror it for non-vi contexts.)
bindkey "^[[A" hist-backward-end
bindkey "^[[B" hist-forward-end

#######################################################
# Completion
#######################################################
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

#######################################################
# Integrations
#######################################################
eval "$(fzf --zsh)"
eval "$(zoxide init zsh)"

#######################################################
# Aliases & functions
#######################################################
source ~/.zsh/alias.zsh
source ~/.zsh/functions.zsh

export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.npm-global/bin:$HOME/.cargo/bin:$PATH"

if command -v fastfetch >/dev/null 2>&1 && [[ -d "$HOME/.local/share/fastfetch" ]]; then
    alias fastfetch='clr && fastfetch --config simple'
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
# Home Manager session variables (set by `home-manager switch`)
if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# Load Nix environment variables
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then
  . $HOME/.nix-profile/etc/profile.d/nix.sh
fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
