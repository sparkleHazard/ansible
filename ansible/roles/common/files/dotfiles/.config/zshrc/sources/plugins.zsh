#!/bin/bash

# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

# Check if the ZAP_DIR environment variable is set and points to an existing directory
if [ -z "$ZAP_DIR" ] || [ ! -d "$ZAP_DIR" ]; then
    echo "ZAP_DIR is not set or does not point to an existing directory."
    echo "Running the zap-install.sh script"
    ~/.config/zshrc/scripts/zap-install.sh
fi

# Plugin declarations
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"
plug "zap-zsh/vim"
plug "wintermi/zsh-starship"
plug "MAHcodes/distro-prompt"
