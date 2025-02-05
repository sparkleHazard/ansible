#!/bin/bash

function dotfiles_rsync {
  # Ensure at least two arguments are provided
  if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [rsync-options] <source> <destination>"
    return 1
  fi

  # Extract the source and destination from the last two arguments
  SOURCE="${@: -2:1}"
  DESTINATION="${@: -1}"

  # Collect all preceding arguments as rsync options
  RSYNC_OPTIONS=("${@:1:$#-2}")

  # Run rsync in dry-run mode with itemized changes
  OUTPUT=$(rsync -av --dry-run --itemize-changes "${RSYNC_OPTIONS[@]}" "$SOURCE" "$DESTINATION")

  # Check if the output indicates any files will be overwritten
  if echo "$OUTPUT" | grep -q '^>f.*'; then
    echo "The following files will be overwritten:"
    echo "$OUTPUT" | grep '^>f.*'
    read -r -p "Are you sure you wish to continue? (y/n): " CONFIRM

    if [[ "$CONFIRM" != "y" ]]; then
      echo "Operation aborted."
      return 1
    fi
  fi

  # Proceed to run the actual rsync command
  rsync -av "${RSYNC_OPTIONS[@]}" "$SOURCE" "$DESTINATION"
}
