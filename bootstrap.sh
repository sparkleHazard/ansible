#!/bin/bash
# bootstrap.sh - OS-agnostic bootstrapping script with role arguments.
#
# This script installs prerequisites (Nix, Ansible, Home Manager),
# fetches an approved SSH key from a local server, and then runs
# ansible-pull with a role specified by the command-line argument.
#
# Usage (via curl pipe to bash):
#   curl -sSL https://provisioning-server.local/bootstrap.sh | bash -s -- --role=webserver
#
# If no role is specified, the default "base" is used.
#
set -euo pipefail

#############################
# Argument Parsing
#############################
# Default role is "base" if not provided.
ROLE="base"

# Parse arguments (e.g. --role=webserver)
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

echo "Bootstrapping role: ${ROLE}"

#############################
# Step 1: OS Detection
#############################
OS="$(uname -s)"
echo "Detected OS: ${OS}"

#############################
# Step 2: Install Nix (if needed)
#############################
if ! command -v nix >/dev/null 2>&1; then
  echo "Nix is not installed. Installing Nix..."
  curl -L https://nixos.org/nix/install | sh
  # Source the Nix profile to update environment variables.
  if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
else
  echo "Nix is already installed."
fi

#############################
# Step 3: Install Ansible (OS-agnostic)
#############################
install_ansible() {
  if command -v ansible-playbook >/dev/null 2>&1; then
    echo "Ansible is already installed."
    return
  fi

  echo "Ansible not found. Installing..."
  case "$OS" in
  Linux)
    if command -v lsb_release >/dev/null 2>&1; then
      DISTRO=$(lsb_release -is)
      echo "Detected Linux distro: ${DISTRO}"
      case "$DISTRO" in
      Ubuntu | Debian)
        sudo apt-get update && sudo apt-get install -y ansible
        ;;
      Fedora)
        sudo dnf install -y ansible
        ;;
      CentOS | RedHat)
        sudo yum install -y epel-release && sudo yum install -y ansible
        ;;
      *)
        echo "Unknown Linux distro ($DISTRO). Falling back to pip installation..."
        pip install --user ansible
        ;;
      esac
    else
      echo "lsb_release not available. Attempting pip installation..."
      pip install --user ansible
    fi
    ;;
  Darwin)
    if command -v brew >/dev/null 2>&1; then
      brew install ansible
    else
      echo "Homebrew not found on macOS. Please install Homebrew first."
      exit 1
    fi
    ;;
  *)
    echo "OS $OS is not explicitly supported. Attempting pip installation..."
    pip install --user ansible
    ;;
  esac
}
install_ansible

#############################
# Step 4: Install Home Manager via Nix (if needed)
#############################
if ! command -v home-manager >/dev/null 2>&1; then
  echo "Home Manager not found. Installing Home Manager..."
  nix profile install nixpkgs#home-manager
else
  echo "Home Manager is already installed."
fi

echo "Home Manager version: $(home-manager --version)"

#############################
# Step 5: Fetch Approved SSH Key from Local Server
#############################
LOCAL_KEY_URL="http://localserver.example.com/approved_key.pub"
echo "Fetching approved SSH key from ${LOCAL_KEY_URL}..."
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

KEY_DEST="${HOME}/.ssh/authorized_keys"
curl -sSf "${LOCAL_KEY_URL}" -o /tmp/approved_key.pub

if [ -f "${KEY_DEST}" ]; then
  if grep -qFf /tmp/approved_key.pub "${KEY_DEST}"; then
    echo "Approved SSH key already present in authorized_keys."
  else
    cat /tmp/approved_key.pub >>"${KEY_DEST}"
    echo "Approved SSH key added to authorized_keys."
  fi
else
  cat /tmp/approved_key.pub >"${KEY_DEST}"
  echo "authorized_keys created and approved SSH key added."
fi
chmod 600 "${KEY_DEST}"

#############################
# Step 6: Run ansible-pull to Provision the System
#############################
# Define your bootstrap repository URL and playbook path.
BOOTSTRAP_REPO="git@github.com:SparkleHazard/bootstrap.git"
PLAYBOOK_PATH="ansible/playbooks/site.yml"

# Define the private key if needed (adjust the path accordingly).
PRIVATE_KEY="/path/to/your/private/key"

echo "Running ansible-pull for role '${ROLE}'..."
ansible-pull -U "${BOOTSTRAP_REPO}" \
  -i "localhost," \
  --playbook "${PLAYBOOK_PATH}" \
  -e "host_role=${ROLE}" \
  --private-key "${PRIVATE_KEY}" \
  --accept-host-key

echo "Bootstrapping complete."
