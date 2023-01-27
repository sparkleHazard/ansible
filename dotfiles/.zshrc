# source antidote
source ${ZDOTDIR:-~}/.antidote/antidote.zsh

# Start zoxide - Smarter version of the 'cd' command
eval "$(zoxide init zsh)"

# Source custom functions
#source $HOME/.tmux_startup

# Source alias file
source $HOME/.aliases

# initialize plugins statically with ${ZDOTDIR:-~}/.zsh_plugins.txt
antidote load

eval "$(starship init zsh)"

export TERM=xterm-256color

export AUTO_TITLE_SCREENS="NO"

export RPROMPT=

# Variables
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=~/.cache/zsh/history

# Fix for vi mode breaking and causing 'starship_zle-keymap-select-wrapped:1: maximum nested function level reached; increase FUNCNEST?' error
function zle-line-init zle-keymap-select {
    RPS1="${${KEYMAP/vicmd/}/(main|viins)/}"
    RPS2=$RPS1
    zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

#check_tokens

fpath=(~/.zsh/completion $fpath)

autoload -Uz promptinit && promptinit && prompt pure > /dev/null 2>&1
autoload -Uz compinit && compinit -i

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#tmux_startup
