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

ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
zinit light jeffreytse/zsh-vi-mode

zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::command-not-found

autoload -Uz compinit && compinit
zinit cdreplay -q

[[ ! -f ~/.zsh/.p10k.zsh ]] || source ~/.zsh/.p10k.zsh

#######################################################
# Options
#######################################################
setopt autocd correct interactivecomments magicequalsubst
setopt nonomatch notify numericglobsort promptsubst

setopt appendhistory sharehistory
setopt hist_ignore_space hist_ignore_all_dups hist_save_no_dups hist_ignore_dups hist_find_no_dups

#######################################################
# Environment
#######################################################
export EDITOR="nvim visudo"
export VISUAL="nvim visudo"
export SUDO_EDITOR=nvim
export FCEDIT=nvim
export HISTSIZE=10000
export HISTFILE=~/.zsh/.zsh_history
export SAVEHIST=$HISTSIZE
export HISTDUP=erase

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
bindkey -v
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward

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
source ~/.zsh/functions.sh

export PATH="$HOME/.local/bin:$PATH"
export PATH=/home/pn/.opencode/bin:$PATH
export PATH="$HOME/.npm-global/bin:$PATH"

if command -v fastfetch &> /dev/null && [[ -d "$HOME/.local/share/fastfetch" ]]; then
    alias fastfetch='clr && fastfetch --config simple'
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
