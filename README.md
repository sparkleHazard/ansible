# Bootstrap

A self-contained, OS-agnostic provisioning repository for bootstrapping and configuring new systems using ansible‑pull, Nix, Home Manager, and your dotfiles.

This repository provides a one‑step method to get a new machine up and running. By running a single bootstrap command (via curl piping into bash), the system will automatically:

- Install prerequisites (Nix, Ansible, Home Manager) in an OS‑agnostic way.
- Fetch an approved SSH key from a local key server.
- Pull down your provisioning repository from GitHub.
- Run an ansible‑pull based playbook that applies roles based on a role argument (e.g. base, webserver, etc.).
- Deploy your dotfiles (stored as a submodule) using rsync so that local changes can be tested if needed.

## Overview

This repository is designed to be used as a bootstrap or provisioning repo. It supports:
- **Self-Provisioning via ansible‑pull:**  
  Each new machine pulls its configuration locally. There’s no need for a centralized, static inventory file.
- **OS-Agnostic Prerequisite Installation:**  
  The bootstrap script detects your operating system (Linux or macOS) and installs Nix, Ansible, and Home Manager using the appropriate package manager or installer.
- **Modular Roles:**  
  The repository includes roles for base system configuration, common dotfiles distribution, and role‑specific tasks (e.g. webserver configuration). Roles can be controlled via a command‑line argument when bootstrapping.
- **Easy Extensibility:**  
  Add new roles by creating a new role directory under `ansible/roles` and update your playbook to conditionally include them based on variables.

## Directory Structure

```
bootstrap/ ├── ansible │   ├── inventory.yml # (Not strictly needed with ansible-pull; defaults to localhost) │   ├── playbooks │   │   └── site.yml # Main playbook that includes roles based on a host variable (e.g., host_role) │   └── roles │   ├── base # Base role: common system configuration (OS-agnostic package updates via Homebrew) │   │   └── tasks │   │   └── main.yml │   ├── common # Common role: deploy dotfiles from a submodule using rsync │   │   ├── files │   │   │   └── dotfiles # Git submodule pointing to your dotfiles repository │   │   └── tasks │   │   └── main.yml │   └── webserver # Webserver role: tasks specific to a web server (optional) │   └── tasks │   └── main.yml ├── nix │   └── flake.nix # Home Manager/NixOS configuration for a reproducible environment └── bootstrap.sh # OS-agnostic bootstrap script that accepts arguments (e.g., --role=webserver)
```

## Usage

### Bootstrapping a New Machine

To bootstrap a new system, simply run the following one‑liner (make sure the provisioning server is set up to serve `bootstrap.sh`):

```bash
curl -sSL https://provisioning-server.local/bootstrap.sh | bash -s -- --role=webserver
```

Replace webserver with the desired role (for example, base or any custom role you define). If no role is specified, the default is base.
### What the Bootstrap Script Does

- OS Detection & Prerequisite Installation:
  - Detects your operating system and installs Nix, Ansible (using apt, dnf, Homebrew, or pip as appropriate), and Home Manager via Nix.
  - SSH Key Distribution:
      Downloads an approved SSH key from your local key server and appends it to your ~/.ssh/authorized_keys.
  - ansible‑pull Invocation:
      Runs ansible‑pull to clone/update the provisioning repository and execute the main playbook (ansible/playbooks/site.yml), passing the host_role extra variable so that the correct roles are applied.

## Role Customization

- Base Role:
    The base role (in ansible/roles/base) is OS‑agnostic. It first updates system packages (using Homebrew on macOS and Linux) and installs common packages defined in variables.
- Common Role:
    The common role (in ansible/roles/common) updates the dotfiles submodule and deploys your configuration files to your home directory using rsync (with the --update flag so local modifications can be preserved for testing).
- Webserver Role:
    The webserver role (in ansible/roles/webserver) contains tasks specific to web servers. Additional roles can be added by following the same pattern.

## Extending the System

You can add new roles by:

- Creating a new directory under `ansible/roles` (e.g., `database`).
- Writing tasks in `ansible/roles/database/tasks/main.yml`.
- Updating your main playbook (`ansible/playbooks/site.yml`) to conditionally  include the new role based on a variable (for example, using a when: `host_role == "database"` condition) or by using multiple plays for different groups.

## Contributing

Contributions are welcome! If you have suggestions or improvements for this bootstrapping system, please open an issue or submit a pull request.
License

This project is licensed under the MIT License. See LICENSE for details.

---

This README provides an overview of the repository, explains how to use the bootstrap script (including passing a role as an argument), outlines the directory structure, and describes how to extend or customize the provisioning. Feel free to modify any section to better fit your exact setup.
