#!/bin/bash
# bootstrap.sh - OS-agnostic bootstrapping script with role arguments,
# including retries, logging, dedicated brewuser creation for Homebrew installation,
# conditional multi-user Nix setup, and automatic ansible-pull.
#
# This script installs prerequisites (sudo, curl, Git, rsync, Nix),
# sets up Nix multi-user mode (if running as root),
# installs Nix (multi-user if root, single-user otherwise),
# and if running as root, creates a dedicated brewuser to install Homebrew.
#
# It then fetches the GitHub SSH private key via rsync (if role is not keyserver)
# or, if role is keyserver, generates an ECDSA key pair and pauses to let you upload its public key.
#
# Finally, it runs ansible-pull (using the appropriate SSH key) with the specified role.
#
# Usage (via curl pipe to bash):
#   curl -sSL https://provisioning-server.local/bootstrap.sh | bash -s -- --role=webserver [--verbose]
#
# If no role is specified, the default "base" is used.
#
set -euo pipefail

#############################
# Parse Arguments
#############################
ROLE="base"
VERBOSE=false
for arg in "$@"; do
  case $arg in
  --role=*)
    ROLE="${arg#*=}"
    shift
    ;;
  --verbose)
    VERBOSE=true
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [--role=ROLE] [--verbose]"
    exit 0
    ;;
  *)
    echo "Unknown parameter passed: $arg"
    exit 1
    ;;
  esac
done

#############################
# Progress Message Functions
#############################
progress() {
  if [ "$VERBOSE" = true ]; then
    echo "==> $@"
  else
    echo -n "==> $@ ... "
  fi
}

done_progress() {
  if [ "$VERBOSE" = false ]; then
    echo "done."
  fi
}

#############################
# Logging Function (unbuffered)
#############################
log() {
  stdbuf -o0 echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

#############################
# Retry Function
#############################
retry_command() {
  local max_retries=$1
  shift
  local sleep_seconds=$1
  shift
  local count=0
  until "$@"; do
    count=$((count + 1))
    if [ "$count" -ge "$max_retries" ]; then
      log "Command failed after $count attempts: $*"
      return 1
    fi
    log "Command failed, retrying in $sleep_seconds seconds... (Attempt $((count + 1))/$max_retries)"
    sleep "$sleep_seconds"
  done
  return 0
}

#############################
# Debug: Show EUID
#############################
echo "EUID is: $EUID"

#############################
# Step 2: OS Detection
#############################
OS="$(uname -s)"
log "Detected OS: ${OS}"

#############################
# Step 3: Ensure sudo is installed (if needed)
#############################
progress "Checking sudo installation"
if [ "$(id -u)" -eq 0 ]; then
  log "Running as root."
  if ! command -v sudo >/dev/null 2>&1; then
    log "sudo is not installed. Installing sudo..."
    case "$OS" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y sudo
      elif command -v yum >/dev/null 2>&1; then
        yum install -y sudo
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sudo
      else
        log "Unable to determine package manager to install sudo."
        exit 1
      fi
      ;;
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install sudo
      else
        log "Homebrew not found on macOS. Please install sudo manually."
        exit 1
      fi
      ;;
    *)
      log "OS $OS not explicitly supported for sudo installation. Please install sudo manually."
      exit 1
      ;;
    esac
  else
    log "sudo is already installed."
  fi
else
  log "Running as non-root user."
  if ! command -v sudo >/dev/null 2>&1; then
    log "Error: sudo is not installed and you are not root. Please install sudo or run as root."
    exit 1
  fi
fi
done_progress

#############################
# Step 4: Ensure curl is installed (OS-agnostic)
#############################
progress "Checking curl installation"
if ! command -v curl >/dev/null 2>&1; then
  log "curl is not installed. Installing curl..."
  case "$OS" in
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y curl
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y curl
    else
      log "Unable to determine package manager. Please install curl manually."
      exit 1
    fi
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install curl
    else
      log "Homebrew not found on macOS. Please install Homebrew and then curl."
      exit 1
    fi
    ;;
  *)
    log "Unsupported OS for automatic curl installation. Please install curl manually."
    exit 1
    ;;
  esac
else
  log "curl is already installed."
fi
done_progress

#############################
# Step 4.5: Ensure Git is installed (OS-agnostic)
#############################
progress "Checking Git installation"
if ! command -v git >/dev/null 2>&1; then
  log "Git is not installed. Installing Git..."
  case "$OS" in
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y git
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y git
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y git
    else
      log "Unable to determine package manager for Git installation on Linux. Please install Git manually."
      exit 1
    fi
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install git
    else
      log "Homebrew not found on macOS. Please install Git manually or install Homebrew first."
      exit 1
    fi
    ;;
  *)
    log "Unsupported OS for automatic Git installation. Please install Git manually."
    exit 1
    ;;
  esac
else
  log "Git is already installed."
fi
done_progress

#############################
# Step 4.75: Ensure rsync is installed (OS-agnostic)
#############################
progress "Checking rsync installation"
if ! command -v rsync >/dev/null 2>&1; then
  log "rsync is not installed. Installing rsync..."
  case "$OS" in
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y rsync
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y rsync
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y rsync
    else
      log "Unable to determine package manager for rsync installation on Linux. Please install rsync manually."
      exit 1
    fi
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install rsync
    else
      log "Homebrew not found on macOS. Please install rsync manually or install Homebrew first."
      exit 1
    fi
    ;;
  *)
    log "Unsupported OS for automatic rsync installation. Please install rsync manually."
    exit 1
    ;;
  esac
else
  log "rsync is already installed."
fi
done_progress

#############################
# Step 5: Install Nix (if needed)
#############################
progress "Checking Nix installation"
if command -v nix >/dev/null 2>&1; then
  NIX_VERSION=$(nix --version 2>/dev/null)
  if [[ $NIX_VERSION == nix-* ]] || [ -d "/nix/store" ]; then
    log "Nix is already installed: $NIX_VERSION"
  else
    log "Nix command exists but /nix/store not found; proceeding to install Nix..."
    if [[ $EUID -eq 0 ]]; then
      log "Installing Nix in multi-user mode..."
      curl -L https://nixos.org/nix/install | sh
    else
      log "Installing Nix in single-user mode..."
      export NIX_MULTI_USER_ENABLE=0
      if [ ! -d "/nix" ]; then
        log "Directory /nix does not exist; attempting to create it using sudo."
        sudo mkdir -m 0755 /nix && sudo chown "$USER" /nix
      fi
      curl -L https://nixos.org/nix/install | sh
    fi
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
  fi
else
  log "Nix command not found. Installing Nix..."
  if [[ $EUID -eq 0 ]]; then
    log "Installing Nix in multi-user mode..."
    curl -L https://nixos.org/nix/install | sh
  else
    log "Installing Nix in single-user mode..."
    export NIX_MULTI_USER_ENABLE=0
    if [ ! -d "/nix" ]; then
      log "Directory /nix does not exist; attempting to create it using sudo."
      sudo mkdir -m 0755 /nix && sudo chown "$USER" /nix
    fi
    curl -L https://nixos.org/nix/install | sh
  fi
  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
fi
done_progress

#############################
# Step 5.5: Setup Nix Multi-User Environment (only if running as root)
#############################
if [[ $EUID -eq 0 ]]; then
  progress "Setting up Nix multi-user environment"
  log "Running as root. Proceeding with Nix multi-user setup."
  if ! getent group nixbld >/dev/null; then
    log "Creating group 'nixbld'..."
    groupadd -r nixbld
  fi

  for n in $(seq 1 10); do
    USERNAME="nixbld$n"
    if ! id "$USERNAME" >/dev/null 2>&1; then
      log "Creating build user $USERNAME..."
      useradd -c "Nix build user $n" -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(which nologin)" "$USERNAME"
    else
      log "Build user $USERNAME already exists."
    fi
    usermod -a -G nixbld "$USERNAME"
  done
  log "Nix build users group (nixbld) membership: $(getent group nixbld)"

  if ! pgrep -x nix-daemon >/dev/null; then
    log "Starting nix-daemon..."
    nix-daemon &
    sleep 5
  fi

  export NIX_REMOTE=daemon
  log "Exported NIX_REMOTE=daemon"
  done_progress
else
  log "Not running as root (EUID=$EUID): Skipping Nix multi-user environment setup."
  done_progress
fi

#############################
# Step 6: Install Ansible (OS-agnostic)
#############################
progress "Checking Ansible installation"
install_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    log "Ansible is already installed."
    return
  fi
  log "Ansible not found. Installing..."
  case "$OS" in
  Linux)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      DISTRO="${ID:-Unknown}"
    else
      DISTRO="$(uname -s)"
    fi
    DISTRO=$(echo "$DISTRO" | tr '[:lower:]' '[:upper:]')
    log "Detected Linux distro: ${DISTRO}"
    case "$DISTRO" in
    UBUNTU | DEBIAN)
      sudo apt-get update && sudo apt-get install -y ansible
      ;;
    FEDORA)
      sudo dnf install -y ansible
      ;;
    CENTOS | REDHAT)
      sudo yum install -y epel-release && sudo yum install -y ansible
      ;;
    *)
      log "Unknown Linux distro ($DISTRO). Falling back to pip installation..."
      pip install --user ansible
      ;;
    esac
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install ansible
    else
      log "Homebrew not found on macOS. Please install Homebrew first."
      exit 1
    fi
    ;;
  *)
    log "OS $OS is not explicitly supported. Attempting pip installation..."
    pip install --user ansible
    ;;
  esac
}
install_ansible
done_progress

#############################
# Step 7: (Optional) Home Manager installation (commented out)
#############################
# progress "Checking Home Manager installation"
# if ! command -v home-manager >/dev/null 2>&1; then
#   log "Home Manager not found. Installing Home Manager..."
#   nix profile install nixpkgs#home-manager
# else
#   log "Home Manager is already installed."
# fi
# log "Home Manager version: $(home-manager --version)"
# done_progress

#############################
# Step 8: Fetch GitHub SSH Private Key via rsync (if not keyserver)
#############################
if [ "$ROLE" != "keyserver" ]; then
  progress "Fetching GitHub SSH private key via rsync"
  GITHUB_KEY_URL="rsync://192.168.1.8/keys/id_ecdsa_github"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  PRIVATE_KEY_DEST="${HOME}/.ssh/id_ecdsa_github"

  retry_command 5 10 rsync -avz "${GITHUB_KEY_URL}" /tmp/github_key
  if [ $? -ne 0 ]; then
    log "Error: Unable to fetch GitHub SSH private key from ${GITHUB_KEY_URL} after retries."
    exit 1
  fi

  if [ -f "${PRIVATE_KEY_DEST}" ]; then
    if cmp -s /tmp/github_key "${PRIVATE_KEY_DEST}"; then
      log "GitHub SSH private key is already up-to-date."
    else
      cp /tmp/github_key "${PRIVATE_KEY_DEST}"
      log "GitHub SSH private key updated at ${PRIVATE_KEY_DEST}."
    fi
  else
    cp /tmp/github_key "${PRIVATE_KEY_DEST}"
    log "GitHub SSH private key installed at ${PRIVATE_KEY_DEST}."
  fi
  chmod 600 "${PRIVATE_KEY_DEST}"
  done_progress
else
  log "Role is 'keyserver'. Skipping GitHub SSH private key fetch."
  done_progress
fi

#############################
# Step 9: Keyserver-Specific: Generate ECDSA SSH Key Pair and Conditionally Pause
#############################
if [ "$ROLE" == "keyserver" ]; then
  progress "Generating ECDSA SSH key pair for keyserver"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  KEY_PATH="${HOME}/.ssh/id_ecdsa_keyserver"
  if [ ! -f "${KEY_PATH}" ]; then
    ssh-keygen -t ecdsa -b 521 -f "${KEY_PATH}" -N "" -q
    log "ECDSA key pair generated at ${KEY_PATH}."
    NEW_KEY=true
  else
    log "ECDSA key pair already exists at ${KEY_PATH}."
    NEW_KEY=false
  fi

  PUBLIC_KEY=$(cat "${KEY_PATH}.pub")
  log "Public key for GitHub (upload this key to GitHub if not already done):"
  echo "${PUBLIC_KEY}"

  if [ "$NEW_KEY" = true ]; then
    echo "Press Enter to continue after you have added the public key to GitHub..."
    read -r
  else
    log "Key already exists; skipping pause."
  fi
  done_progress
fi

#############################
# Step 10: Run ansible-pull to Provision the System
#############################
progress "Running ansible-pull"
ANSIBLE_PRIVATE_KEY="${HOME}/.ssh/id_ecdsa_github"
log "Using SSH key at ${ANSIBLE_PRIVATE_KEY} for ansible-pull."

# Assumes that the repository root contains a file named "site.yml" that imports your actual playbook.
ansible-pull -U "git@github.com:sparkleHazard/bootstrap.git" \
  -i "localhost," \
  --extra-vars "host_role=${ROLE}" \
  --private-key "${ANSIBLE_PRIVATE_KEY}" \
  --accept-host-key \
  ansible/site.yml
done_progress

log "Bootstrapping complete."
