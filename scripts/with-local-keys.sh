#!/usr/bin/env bash
# Runs a command in the toolbox with the ssh keys of the local VM in place:
#
#   scripts/with-local-keys.sh ansible-playbook ansible/playbooks/site.yml
#
# - Creates the deploy key pair in local/.ssh/ on first use (gitignored).
# - Copies it and the key Vagrant generated for the `vagrant` user into
#   /root/.ssh/uptime-local with mode 0600. On a Windows bind mount every
#   file looks world-readable, and ssh refuses such private keys.
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

exec "$@"
