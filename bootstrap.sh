#!/bin/bash
# bootstrap.sh - Improved, modular bootstrap script
#
# This script:
#   - Parses arguments (--role, --verbose, --mise-install)
#   - Sets up logging and helper functions
#   - Ensures prerequisites (sudo, curl, Git, rsync, jq, Ansible, GitHub CLI) are installed
#   - Verifies that the ~/.ssh directory exists
#   - For the keyserver role:
#         * Prompts for a GitHub token if needed and verifies GitHub CLI authentication
#         * Generates an ECDSA SSH key pair (if not present)
#         * Tests SSH access to GitHub using that key, and if access is denied, updates the GitHub key
#   - For non-keyserver roles, fetches the GitHub SSH private key via rsync
#   - Runs ansible-pull with the appropriate SSH key and vault password file
#   - Optionally creates a one-shot systemd service (if --mise-install is passed) that executes
#     "/home/linuxbrew/.linuxbrew/bin/mise install" once after reboot, then reboots the host.
#
# Usage (via curl pipe to bash):
#   curl -sSL https://provisioning-server.local/bootstrap.sh | bash -s -- --role=webserver [--verbose] [--mise-install]
# If no role is specified, the default "base" is used.

set -euo pipefail

#############################
# Configuration Variables
#############################
REPO_URL="git@github.com:sparkleHazard/ansible.git"
VAULT_PASS_FILE="$HOME/.vault_pass.txt"
ANSIBLE_SITE="ansible/site.yml"
# The path for mise install command:
MISE_CMD="/home/linuxbrew/.linuxbrew/bin/mise install"

#############################
# Global Variables (set via arguments)
#############################
ROLE="base"
VERBOSE=false
RUN_MISE_INSTALL=false

#############################
# Argument Parsing Function
#############################
parse_args() {
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
    --mise-install)
      RUN_MISE_INSTALL=true
      shift
      ;;
    -h | --help)
      echo "Usage: $0 [--role=ROLE] [--verbose] [--mise-install]"
      exit 0
      ;;
    *)
      echo "Unknown parameter passed: $arg"
      exit 1
      ;;
    esac
  done
}
parse_args "$@"

#############################
# Logging and Progress Functions
#############################
progress() {
  if [ "$VERBOSE" = true ]; then
    echo "==> $*"
  else
    echo -n "==> $* ... "
  fi
}

done_progress() {
  if [ "$VERBOSE" = false ]; then
    echo "done."
  fi
}

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
# Ensure .ssh Directory Exists
#############################
ensure_ssh_directory() {
  progress "Verifying .ssh directory"
  if [ -d "${HOME}/.ssh" ]; then
    log ".ssh directory exists."
  else
    log ".ssh directory not found. Creating ~/.ssh directory..."
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"
  fi
  done_progress
}
ensure_ssh_directory

#############################
# Ensure Prerequisites Functions
#############################
ensure_sudo() {
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
}

ensure_curl() {
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
}

ensure_git() {
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
}

ensure_rsync() {
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
}

ensure_jq() {
  progress "Checking jq installation"
  if ! command -v jq >/dev/null 2>&1; then
    log "jq is not installed. Installing jq..."
    case "$OS" in
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y jq
      elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y jq
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y jq
      else
        log "Unable to determine package manager for jq installation on Linux. Please install jq manually."
        exit 1
      fi
      ;;
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install jq
      else
        log "Homebrew not found on macOS. Please install jq manually or install Homebrew first."
        exit 1
      fi
      ;;
    *)
      log "Unsupported OS for automatic jq installation. Please install jq manually."
      exit 1
      ;;
    esac
  else
    log "jq is already installed."
  fi
  done_progress
}

ensure_ansible() {
  progress "Checking Ansible installation"
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
  done_progress
}

ensure_gh() {
  progress "Checking GitHub CLI (gh) installation"
  if ! command -v gh >/dev/null 2>&1; then
    log "GitHub CLI (gh) not found. Installing GitHub CLI..."
    case "$OS" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install gh
      else
        log "Homebrew not found on macOS. Please install GitHub CLI manually."
        exit 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
        sudo apt-get update
        sudo apt-get install -y gh
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install -y gh
      elif command -v yum >/dev/null 2>&1; then
        sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo yum install -y gh
      else
        log "Please install GitHub CLI (gh) manually on Linux."
        exit 1
      fi
      ;;
    *)
      log "Unsupported OS for automatic GitHub CLI installation. Please install gh manually."
      exit 1
      ;;
    esac
  else
    log "GitHub CLI (gh) is already installed."
  fi
  done_progress
}

# Execute prerequisite checks
ensure_sudo
ensure_curl
ensure_git
ensure_rsync
ensure_jq
ensure_ansible
ensure_gh

#############################
# Step 3.1: Keyserver-Specific: Verify GitHub CLI Authentication
#############################
if [ "$ROLE" == "keyserver" ]; then
  progress "Verifying GitHub CLI authentication"
  if ! gh auth status >/dev/null 2>&1; then
    log "GitHub CLI is not authenticated."
    read -r -p "Please enter your GitHub Personal Access Token: " TOKEN_INPUT
    if [ -z "$TOKEN_INPUT" ]; then
      log "No token provided, aborting."
      exit 1
    fi
    export GH_TOKEN="$TOKEN_INPUT"
    if ! gh auth status >/dev/null 2>&1; then
      log "GitHub CLI authentication failed even after setting GH_TOKEN. Aborting."
      exit 1
    fi
  fi
  done_progress
fi

#############################
# Step 3.2: Keyserver-Specific: Manage SSH Key for GitHub
#############################
if [ "$ROLE" == "keyserver" ]; then
  progress "Generating and validating ECDSA SSH key for keyserver"
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  KEY_PATH="${HOME}/.ssh/id_ecdsa_github"
  if [ ! -f "${KEY_PATH}" ]; then
    ssh-keygen -t ecdsa -b 521 -f "${KEY_PATH}" -N "" -q -C ""
    log "ECDSA key pair generated at ${KEY_PATH}."
    NEW_KEY=true
  else
    log "ECDSA key pair already exists at ${KEY_PATH}."
    NEW_KEY=false
  fi

  PUBLIC_KEY=$(cat "${KEY_PATH}.pub")
  log "Local public key for GitHub:"
  echo "${PUBLIC_KEY}"

  # Test SSH access to GitHub using the local key.
  SSH_TEST=$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=no -i "${KEY_PATH}" git@github.com 2>&1 || true)
  if echo "$SSH_TEST" | grep -qi "successfully authenticated"; then
    log "SSH key is accepted by GitHub."
  else
    log "SSH key access denied. Updating GitHub key..."
    if command -v gh >/dev/null 2>&1; then
      KEY_TITLE="keyserver"
      EXISTING_KEY_ID=$(gh api -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /user/keys | jq -r ".[] | select(.title==\"$KEY_TITLE\") | .id")
      if [ -n "$EXISTING_KEY_ID" ]; then
        log "Deleting old GitHub key with ID: $EXISTING_KEY_ID"
        gh api --method DELETE -H "Accept: application/vnd.github+json" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          /user/keys/"$EXISTING_KEY_ID"
      fi
      log "Adding new SSH key to GitHub..."
      gh api --method POST -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        /user/keys -f "key=${PUBLIC_KEY}" -f "title=${KEY_TITLE}"
    else
      log "GitHub CLI (gh) not found. Cannot update GitHub key automatically."
    fi
  fi

  if [ "$NEW_KEY" = true ]; then
    read -r -p "Press Enter to continue after verifying the public key on GitHub..."
  else
    log "Key already exists; skipping pause."
  fi
  done_progress
fi

#############################
# Step 4: Fetch GitHub SSH Private Key via rsync (for non-keyserver roles)
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
# Step 5: Run ansible-pull to Provision the System
#############################
run_ansible_pull() {
  progress "Running ansible-pull"
  ANSIBLE_PRIVATE_KEY="${HOME}/.ssh/id_ecdsa_github"
  log "Using SSH key at ${ANSIBLE_PRIVATE_KEY} for ansible-pull."
  ansible-pull -U "$REPO_URL" \
    -i "localhost," \
    --extra-vars "host_role=${ROLE}" \
    --private-key "${ANSIBLE_PRIVATE_KEY}" \
    --accept-host-key \
    --vault-password-file "$VAULT_PASS_FILE" \
    "$ANSIBLE_SITE"
  done_progress
}
run_ansible_pull

#############################
# Step 6: One-Shot Service for 'mise install'
#############################
setup_mise_install_service() {
  progress "Setting up one-shot service to run 'mise install' after reboot"
  TARGET_USER=${SUDO_USER:-$USER}
  TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
  cat <<EOF | sudo tee /etc/systemd/system/mise-install-once.service
[Unit]
Description=Run mise install once after reboot
After=network.target

[Service]
Type=oneshot
User=${TARGET_USER}
Environment=HOME=${TARGET_HOME}
ExecStart=/bin/zsh -i -c "$MISE_CMD"
ExecStartPost=/bin/systemctl disable mise-install-once.service && /bin/rm -f /etc/systemd/system/mise-install-once.service && /bin/systemctl daemon-reload

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable mise-install-once.service
  log "One-shot service created and enabled. Rebooting now..."
  sudo reboot
}

if [ "$RUN_MISE_INSTALL" = true ]; then
  setup_mise_install_service
else
  log "Mise install flag not set. Skipping one-shot service setup."
fi

log "Bootstrapping complete."
