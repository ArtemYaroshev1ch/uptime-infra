# ansible

Host and stack configuration. Ansible runs inside the toolbox container
(`docs/adr/0002-toolbox-container.md`); `make` targets wrap every command.

## Layout

| Path | What |
|---|---|
| `ansible.cfg` | Settings (read through `ANSIBLE_CONFIG`, set in the toolbox) |
| `requirements.yml` | Collections, pinned; baked into the toolbox image |
| `inventories/local/` | The Vagrant VM (`local/Vagrantfile`), the primary environment |
| `inventories/prod/` | Production; `hosts.yml` is generated from Terraform (Phase 5) |
| `playbooks/bootstrap.yml` | First login: creates the `deploy` user |
| `playbooks/site.yml` | Full host configuration |
| `playbooks/verify.yml` | Read-only checks of the result |
| `roles/` | One README per role |
| `molecule/default/` | Idempotence test in a systemd container (ADR-0004) |

## Roles

| Role | Tag | What it does |
|---|---|---|
| [`common`](roles/common/README.md) | `common` | Packages, UTC, unattended security upgrades, sysctl |
| [`ssh_hardening`](roles/ssh_hardening/README.md) | `ssh` | Keys only, no root, `AllowUsers`, modern algorithms; `sshd -t` before reload |
| [`firewall`](roles/firewall/README.md) | `firewall` | ufw: deny incoming except ssh (rate-limited), 80, 443 |
| [`fail2ban`](roles/fail2ban/README.md) | `fail2ban` | sshd jail from the journal |
| [`docker`](roles/docker/README.md) | `docker` | Docker Engine + Compose, pinned, log rotation, live-restore |

## Local environment

```sh
make local-up            # vagrant up + bootstrap.yml + site.yml
make local-check         # site.yml --check --diff
make local-idempotence   # site.yml again, fails unless changed=0
make local-verify        # no password/root login, ufw active, Docker runs
make local-ssh           # shell on the VM (vagrant user)
make local-halt          # stop the VM
```

How the pieces connect:

1. Vagrant (on the host) creates the VM at `192.168.56.10` and a key for the
   `vagrant` user in `local/.vagrant/`.
2. `scripts/with-local-keys.sh` (in the toolbox) creates the `deploy` key
   pair in `local/.ssh/` on first use (gitignored) and copies both keys to
   `/root/.ssh/uptime-local` with mode 0600: ssh refuses private keys that
   look world-readable, and on a Windows bind mount every file does.
3. `bootstrap.yml` logs in as `vagrant`, creates `deploy` with the key and
   passwordless sudo.
4. `site.yml` logs in as `deploy` from then on.

## The deploy user and sudo

`deploy` has no password and `NOPASSWD` sudo: Ansible needs
non-interactive privilege escalation, and an account without a password
cannot be brute-forced. The key is the single secret that grants root, so
it lives only in the operator's ssh agent and the `SSH_PRIVATE_KEY`
GitHub secret. A stricter setup (sudo password from Vault via
`ansible_become_password`) is possible later without changing the roles.

## Tests

- `make lint` runs `ansible-lint` (profile `production`, `.ansible-lint`),
  which includes a syntax check of every playbook.
- `make test-ansible` runs Molecule: `site.yml` twice, the second run must
  report `changed=0`, then `verify.yml`.
