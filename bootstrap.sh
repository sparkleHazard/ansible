#!/bin/bash
# bootstrap.sh - OS-agnostic bootstrapping script with role arguments,
# including retries, logging, keyserver-specific key generation, sudo and curl installation,
# and setup of Nix multi-user mode.
#
# This script installs prerequisites (sudo, curl, Nix, Git, Ansible, Home Manager),
# sets up Nix multi-user mode (creates the nixbld group and build users, starts nix-daemon,
# exports NIX_REMOTE=daemon),
# fetches an approved SSH public key from a local key server (unless the role is "keyserver"),
# securely downloads the GitHub SSH private key (unless the role is "keyserver"),
# and if the role is "keyserver" it generates an ECDSA key pair and prints the public key.
# It then pauses to allow you to upload the public key to GitHub before continuing,
# and finally runs ansible-pull with the specified role.
#
# Usage (via curl pipe to bash):
#   curl -sSL https://provisioning-server.local/bootstrap.sh | bash -s -- --role=webserver
#
# If no role is specified, the default "base" is used.
#
set -euo pipefail

#############################
# Logging & Retry Functions
#############################
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

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
# Step 1: Argument Parsing
#############################
ROLE="base"
while [[ "$#" -gt 0 ]]; do
  case $1 in
  --role=*)
    ROLE="${1#*=}"
    shift
    ;;
  -h | --help)
    echo "Usage: $0 [--role=ROLE]"
    exit 0
    ;;
  *)
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
done
log "Bootstrapping role: ${ROLE}"

#############################
# Step 2: OS Detection
#############################
OS="$(uname -s)"
log "Detected OS: ${OS}"

#############################
# Step 3: Ensure sudo is installed (if running as root)
#############################
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

#############################
# Step 4: Ensure curl is installed (OS-agnostic)
#############################
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

#############################
# Step 4.5: Ensure Git is installed (OS-agnostic)
#############################
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

#############################
# Step 5: Install Nix (if needed)
#############################
# Create the nixbld group if it doesn't exist.
if ! getent group nixbld >/dev/null; then
  log "Creating group 'nixbld'..."
  groupadd -r nixbld
fi

# Create 10 build users (nixbld1 to nixbld10) if they are not already present,
# and add them as explicit members of the nixbld group.
for n in $(seq 1 10); do
  USER="nixbld$n"
  if ! id "$USER" >/dev/null 2>&1; then
    log "Creating build user $USER..."
    useradd -c "Nix build user $n" -d /var/empty -g nixbld -G nixbld -M -N -r -s "$(which nologin)" "$USER"
  else
    log "Build user $USER already exists."
  fi
  # Ensure the user is explicitly listed as a member of nixbld.
  usermod -a -G nixbld "$USER"
done
log "Nix build users group (nixbld) membership: $(getent group nixbld)"

if ! command -v nix >/dev/null 2>&1; then
  log "Nix is not installed. Installing Nix..."
  curl -L https://nixos.org/nix/install | sh
  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
else
  log "Nix is already installed."
fi

#############################
# Step 5.5: Setup Nix Multi-User Environment
#############################
# Start the nix-daemon if not already running.
if ! pgrep -x nix-daemon >/dev/null; then
  log "Starting nix-daemon..."
  nix-daemon &
  sleep 5 # Allow some time for the daemon to start.
fi

# Export NIX_REMOTE for unprivileged users.
export NIX_REMOTE=daemon
log "Exported NIX_REMOTE=daemon"

#############################
# Step 6: Install Ansible (OS-agnostic)
#############################
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

#############################
# Step 7: Install Home Manager via Nix (if needed)
#############################
# if ! command -v home-manager >/dev/null 2>&1; then
#   log "Home Manager not found. Installing Home Manager..."
#   nix profile install nixpkgs#home-manager
# else
#   log "Home Manager is already installed."
# fi
# log "Home Manager version: $(home-manager --version)"

#############################
# Step 8: Fetch Approved SSH Public Key (if not keyserver)
#############################
if [ "$ROLE" != "keyserver" ]; then
  LOCAL_KEY_URL="http://localserver.example.com/approved_key.pub"
  log "Fetching approved SSH public key from ${LOCAL_KEY_URL}..."
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  KEY_DEST="${HOME}/.ssh/authorized_keys"

  retry_command 5 10 curl -sSf "${LOCAL_KEY_URL}" -o /tmp/approved_key.pub
  if [ $? -ne 0 ]; then
    log "Error: Unable to fetch approved SSH key from ${LOCAL_KEY_URL} after retries."
    exit 1
  fi

  if ! grep -qFf /tmp/approved_key.pub "${KEY_DEST}" 2>/dev/null; then
    cat /tmp/approved_key.pub >>"${KEY_DEST}"
    log "Approved SSH public key added to authorized_keys."
  else
    log "Approved SSH public key already present in authorized_keys."
  fi
  chmod 600 "${KEY_DEST}"
else
  log "Role is 'keyserver'. Skipping SSH public key fetch."
fi

#############################
# Step 9: Fetch GitHub SSH Private Key (if not keyserver)
#############################
if [ "$ROLE" != "keyserver" ]; then
  GITHUB_KEY_URL="https://secure-internal.example.com/github_key"
  log "Fetching GitHub SSH private key from ${GITHUB_KEY_URL}..."
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  PRIVATE_KEY_DEST="${HOME}/.ssh/id_rsa_github"

  retry_command 5 10 curl -sSf "${GITHUB_KEY_URL}" -o /tmp/github_key
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
else
  log "Role is 'keyserver'. Skipping GitHub SSH private key fetch."
fi

#############################
# Step 10: Keyserver-Specific: Generate ECDSA SSH Key Pair and Pause
#############################
if [ "$ROLE" == "keyserver" ]; then
  log "Role is keyserver: Generating ECDSA SSH key pair..."
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  KEY_PATH="${HOME}/.ssh/id_ecdsa_github"
  if [ ! -f "${KEY_PATH}" ]; then
    ssh-keygen -t ecdsa -b 521 -f "${KEY_PATH}" -N "" -q
    log "ECDSA key pair generated at ${KEY_PATH}."
  else
    log "ECDSA key pair already exists at ${KEY_PATH}."
  fi

  PUBLIC_KEY=$(cat "${KEY_PATH}.pub")
  log "Public key for GitHub (upload this key to GitHub):"
  echo "${PUBLIC_KEY}"

  echo "Press Enter to continue after you have added the public key to GitHub..."
  read -r
fi

#############################
# Step 11: Run ansible-pull to Provision the System
#############################
BOOTSTRAP_REPO="git@github.com:sparkleHazard/bootstrap.git"
PLAYBOOK_PATH="ansible/playbooks/site.yml"
ANSIBLE_PRIVATE_KEY="${HOME}/.ssh/id_ecdsa_github"

log "Running ansible-pull for role '${ROLE}'..."
ansible-pull -U "${BOOTSTRAP_REPO}" \
  -i "localhost," \
  --extra-vars "host_role=${ROLE}" \
  --private-key "${ANSIBLE_PRIVATE_KEY}" \
  --accept-host-key \
  ansible/site.yml

log "Bootstrapping complete."
