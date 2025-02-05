# Homebrew Setup (macOS & Linux)
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
else
  # Handle different install paths manually
  # Apple Silicon (M1/M2/M3), Intel Macs & some Linux distros and Linuxbrew (Homebrew on Linux)
  for BREW_PREFIX in "/opt/homebrew" "home/linuxbrew/.linuxbrew" "/usr/local"; do 
    if [[ -d "$BREW_PREFIX/bin" ]]; then
      export PATH="$BREW_PREFIX/bin:$PATH"
      export HOMEBREW_PREFIX="$BREW_PREFIX"
      export HOMEBREW_CELLAR="$BREW_PREFIX/Cellar"
      export HOMEBREW_REPOSITORY="$BREW_PREFIX"
      eval "$("$BREW_PREFIX/bin/brew" shellenv)"
      break  # Stop checking after the first valid path is found
    fi
  done
fi
