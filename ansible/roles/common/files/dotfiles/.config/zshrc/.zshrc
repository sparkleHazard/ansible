# Define the sources directory
ZSH_SOURCES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zshrc/sources"

# Source all files in sources directory (ending in .zsh or .sh)
if [[ -d "$ZSH_SOURCES_DIR" ]]; then
  # Temporarily disable nomatch to prevent errors
  setopt +o nomatch

  for file in "$ZSH_SOURCES_DIR"/*.{zsh,sh}; do
    [[ -r "$file" ]] && source "$file"
  done
  unset file

  # Re-enable nomatch
  setopt nomatch
fi

# Load and initialise completion system
autoload -Uz compinit
compinit
