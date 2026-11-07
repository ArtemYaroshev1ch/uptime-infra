#!/usr/bin/env bash
# Runs a command in the toolbox with the ssh keys of the local VM in place:
#
#   scripts/with-local-keys.sh ansible-playbook ansible/playbooks/site.yml
#
# - Creates the deploy key pair in local/.ssh/ on first use (gitignored).
# - Copies it and the key Vagrant generated for the `vagrant` user into
#   /root/.ssh/uptime-local with mode 0600. On a Windows bind mount every
#   file looks world-readable, and ssh refuses such private keys.
# - Creates the local vault on first use (scripts/gen-local-vault.sh) and
#   points ANSIBLE_VAULT_PASSWORD_FILE at a 0600 copy of its password.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_dir="$repo_root/local/.ssh"
vagrant_key="$repo_root/local/.vagrant/machines/default/virtualbox/private_key"
dst_dir=/root/.ssh/uptime-local

if [[ ! -f "$src_dir/deploy" ]]; then
  mkdir -p "$src_dir"
  ssh-keygen -q -t ed25519 -N "" -C "deploy@uptime-local" -f "$src_dir/deploy"
  echo "Created the deploy key pair in local/.ssh/" >&2
fi

install -d -m 0700 "$dst_dir"
install -m 0600 "$src_dir/deploy" "$dst_dir/deploy"
install -m 0644 "$src_dir/deploy.pub" "$dst_dir/deploy.pub"
if [[ -f "$vagrant_key" ]]; then
  install -m 0600 "$vagrant_key" "$dst_dir/vagrant"
fi

# The local vault and its password (created on first use). The copy has
# mode 0600 for the same reason as the keys, and because Ansible would try
# to *execute* a password file that looks executable.
"$repo_root/scripts/gen-local-vault.sh"
install -m 0600 "$repo_root/local/.vault-pass" "$dst_dir/vault-pass"
export ANSIBLE_VAULT_PASSWORD_FILE="$dst_dir/vault-pass"

exec "$@"
