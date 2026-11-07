#!/usr/bin/env bash
# Runs a command in the toolbox with the secrets of the local environment
# in place:
#
#   scripts/with-local-keys.sh ansible-playbook ansible/playbooks/site.yml
#
# - Creates two ssh key pairs in local/.ssh/ on first use (gitignored):
#   `bootstrap` (root's key on the fresh local server, what a cloud
#   provider installs) and `deploy` (the account Ansible uses afterwards).
# - Copies them into /root/.ssh/uptime-local with mode 0600. On a Windows
#   bind mount every file looks world-readable, and ssh refuses such
#   private keys.
# - Creates the local vault on first use (scripts/gen-local-vault.sh) and
#   points ANSIBLE_VAULT_PASSWORD_FILE at a 0600 copy of its password.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_dir="$repo_root/local/.ssh"
dst_dir=/root/.ssh/uptime-local

mkdir -p "$src_dir"
install -d -m 0700 "$dst_dir"
for key in bootstrap deploy; do
  if [[ ! -f "$src_dir/$key" ]]; then
    ssh-keygen -q -t ed25519 -N "" -C "$key@uptime-local" -f "$src_dir/$key"
    echo "Created the $key key pair in local/.ssh/" >&2
  fi
  install -m 0600 "$src_dir/$key" "$dst_dir/$key"
  install -m 0644 "$src_dir/$key.pub" "$dst_dir/$key.pub"
done

# The local vault and its password (created on first use). The copy has
# mode 0600 for the same reason as the keys, and because Ansible would try
# to *execute* a password file that looks executable.
"$repo_root/scripts/gen-local-vault.sh"
install -m 0600 "$repo_root/local/.vault-pass" "$dst_dir/vault-pass"
export ANSIBLE_VAULT_PASSWORD_FILE="$dst_dir/vault-pass"

exec "$@"
