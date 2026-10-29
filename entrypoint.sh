#!/usr/bin/env bash
# Prepares SSH, the vault password and Ansible config, then runs the command.
# Everything mounted from the host is copied with strict permissions, because
# Windows bind mounts show every file as 0777 and ssh/ansible refuse that.
set -euo pipefail

# 1. SSH keys from the host (mounted read-only at /mnt/ssh)
if [ -d /mnt/ssh ]; then
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  for f in /mnt/ssh/id_* /mnt/ssh/config /mnt/ssh/known_hosts; do
    [ -f "$f" ] || continue
    cp "$f" ~/.ssh/
  done
  chmod 600 ~/.ssh/* 2>/dev/null || true
  chmod 644 ~/.ssh/*.pub 2>/dev/null || true
fi

# 2. ssh-agent: the Terraform provider uploads cloud-init snippets with it
if [ -z "${SSH_AUTH_SOCK:-}" ] && ls ~/.ssh/id_* >/dev/null 2>&1; then
  eval "$(ssh-agent -s)" >/dev/null
  for k in ~/.ssh/id_ed25519 ~/.ssh/id_rsa; do
    if [ -f "$k" ]; then ssh-add -q "$k" || true; fi   # asks for the passphrase if the key has one
  done
fi

# 3. Vault password: a 0777 file would be treated as a script by Ansible
if [ -f ~/.ansible/vault_pass ]; then
  install -m 0600 ~/.ansible/vault_pass /tmp/vault_pass
  export ANSIBLE_VAULT_PASSWORD_FILE=/tmp/vault_pass
fi

# 4. Ansible ignores ansible.cfg in a world-writable directory (all Windows
#    mounts are), so point at it explicitly.
if [ -f ./ansible.cfg ]; then
  export ANSIBLE_CONFIG="$PWD/ansible.cfg"
fi

# 5. Git refuses repos owned by another uid (Windows mounts again)
git config --global --add safe.directory '*'

exec "$@"
