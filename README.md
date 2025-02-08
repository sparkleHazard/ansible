# Ansible Configuration Repository

This repository contains an Ansible-based configuration management solution for provisioning and maintaining servers in an OS-agnostic manner. It is designed to work with both the pull model (using `ansible-pull`) and the traditional push model (using `ansible-playbook`).

## Features

- **OS-Agnostic System Updates & Package Management:**

  - Automatically update system packages and install essential development tools.
  - Installs `build-essential` on Debian/Ubuntu, development tools on RedHat/CentOS/Fedora, and common build tools on macOS via Homebrew.

- **Custom Roles:**

  - **base:** Basic configuration for all servers.
  - **keyserver:** Specialized configuration for keyserver deployments (including GitHub SSH key management).
  - **system-updates:** Contains tasks for updating the system and installing prerequisites across multiple OS families.
  - Additional roles can be added as needed.

- **Cloud-init and MOTD Customizations (Optional):**

  - Remove cloud-init from Ubuntu.
  - Customize the Message of the Day (MOTD) – for example, displaying the hostname in a stylized format using figlet.

- **Integration with GitHub CLI and Ansible Vault:**

  - Manage SSH keys on GitHub using the GitHub CLI (`gh`) and update them as needed.
  - Use Ansible Vault to secure sensitive variables (e.g., sudo/become passwords).

- **One-Shot Systemd Service for Post-Reboot Tasks:**
  - Optionally configure a one-shot systemd service (triggered via a bootstrap script argument) to run commands like `mise install` once after a reboot.

## Repository Structure

```plaintext
ansible/
├── group_vars/            # Group variable files (can include vaulted files)
├── host_vars/             # Host-specific variables
├── roles/
│   ├── base/              # Basic server configuration tasks
│   ├── keyserver/         # Keyserver-specific configuration (SSH key management, etc.)
│   ├── system-updates/    # OS-agnostic system update and development tools installation
│   └── [other roles...]
└── site.yml               # Main playbook that includes roles based on extra-vars
```

## Usage

### Using `ansible-pull`

You can bootstrap a new server by running ansible-pull from the target host. For example:

```bash
ansible-pull -U "git@github.com:sparkleHazard/ansible.git" \
  -i "localhost," \
  --extra-vars "host_role=base" \
  --private-key /path/to/your/private/key \
  --accept-host-key \
  --vault-password-file ~/.vault_pass.txt \
  ansible/site.yml
```

### Using `ansible-playbook`

Alternatively, you can run the playbook in a push model from your control machine:

```bash
ansible-playbook -i inventory.ini site.yml \
  --extra-vars "host_role=keyserver" \
  --vault-password-file ~/.vault_pass.txt
```

### Bootstrap Script

A separate bootstrap script is provided (see [bootstrap.sh](https://github.com/sparkleHazard/ansible/blob/main/bootstrap.sh)) that:

- Installs prerequisites (sudo, curl, Git, rsync, jq, Ansible, GitHub CLI)
- Ensures that the ~/.ssh directory exists
- Manages GitHub SSH keys (for keyserver roles)
- Runs ansible-pull to provision the system
- Optionally sets up a one-shot systemd service to run /home/linuxbrew/.linuxbrew/bin/mise install after reboot (using the --mise-install flag)

Prerequisites

- Ansible: Version 2.9 or higher (tested with Ansible 2.14)
- Python: Python 3.x (required by Ansible)
- SSH: Proper SSH keys for repository access and host communication
- Vault: (Optional) A vault password file if you’re using Ansible Vault to secure sensitive variables
  - OS-Specific Requirements:
  - Debian/Ubuntu systems must have access to appropriate repositories.
  - RedHat/CentOS/Fedora systems should have the necessary repository configurations.
  - macOS should have Homebrew installed for package management.

### Contributing

Contributions are welcome! Please open issues or submit pull requests for:

- Improvements and new features
- Bug fixes and documentation enhancements

### License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/sparkleHazard/ansible/blob/main/README.md) file for details.

---

### Final Notes

- **Customization:** Adjust repository URLs, package names, and paths as needed for your environment.
- **Testing:** Ensure you test both `ansible-pull` and `ansible-playbook` modes to confirm that all roles and tasks behave as expected.
- **Documentation:** Keep the README updated as new roles or features are added to the repository.

Let me know if you need any further modifications or additional sections in the README!
