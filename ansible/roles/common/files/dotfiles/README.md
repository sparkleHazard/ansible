# dotfiles

This is an idea that I saw on DistroTube's channel.

I followed instructions from [here](https://stegosaurusdormant.com/bare-git-repo/)

## Installation

1. Create a new bare Git repo to store the history for your dotfiles.

```bash
git init --bare $HOME/dotfiles
```

1. Add this alias to your shell configuration file. This will allow you to use the `dotgit` command to interact with your dotfiles repo.

```bash
# zsh
echo 'alias dotgit="git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"' >> $HOME/.zshrc
source $HOME/.zshrc

# zsh with $XDG_CONFIG_HOME Set
echo 'alias dotgit="git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"' >> $XDG_CONFIG_HOME/.zshrc
source $XDG_CONFIG_HOME/.zshrc

# bash
echo 'alias dotgit="git --git-dir=$HOME/dotfiles/ --work-tree=$HOME"' >> $HOME/.bashrc
source $HOME/.bashrc
```

1. Add this function to your shell configuration file. This adds a check to rsync that will warn if an overwrite is going to occur - This will be useful later when you are configuring a new machine.

```bash
function dotfiles_rsync {
  # Check if the user provided enough arguments
  if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <rsync-options> <source> <destination>"
    return
  fi

  # Extract the rsync options, source, and destination
  RSYNC_OPTIONS="$1"
  SOURCE="$2"
  DESTINATION="$3"

  # Run rsync in dry-run mode with itemized changes
  OUTPUT=$(rsync -av --dry-run --itemize-changes "$RSYNC_OPTIONS" "$SOURCE" "$DESTINATION")

  # Check if the output contains any lines indicating overwrites
  if echo "$OUTPUT" | grep -q '^>f.*'; then
    echo "The following files will be overwritten:"
    echo "$OUTPUT" | grep '^>f.*'
    read -p -r "Are you sure you wish to continue? (y/n): " CONFIRM

    if [[ "$CONFIRM" != "y" ]]; then
      echo "Operation aborted."
      return
    fi
  fi

  # Proceed to run the actual rsync command
  rsync -av "$RSYNC_OPTIONS" "$SOURCE" "$DESTINATION"
}
```

1. Tell Git that this repo should not display all untracked files (otherwise git status will include every file in your home directory, which will make it unusable).

```bash
dotgit config status.showUntrackedFiles no
```

1. Setup a remote repository to push your dotfiles to.

```bash
dotgit remote add origin git@github.com:GregOwen/dotfiles.git
```

1. To add a new dotfile to your Git repo, use your aliased Git command with your special options set.

```bash
dotgit add ~/.gitconfig
dotgit commit -m "Git dotfiles"
dotgit push origin master
```

## Setting up the dotfiles repo on a new machine

1. Clone the repo onto a new machine as a non-bare repository; this will pull a snapshot of the dotfiles into `dotfiles-tmp`

```bash
git clone \
   --separate-git-dir=$HOME/dotfiles \
   git@github.com:SparkleHazard/dotfiles.git \
   dotfiles-tmp
```

1. Copy the snapshot from your temporary directory to the correct locations on your new machine.

```bash
dotfiles_rsync --recursive --verbose --exclude '.git' dotfiles-tmp/ $HOME/
```

1. Clean up

```bash
rm -rf dotfiles-tmp
```

1.
