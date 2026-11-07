# ansible

Host and stack configuration. Ansible runs inside the toolbox container
(`docs/adr/0002-toolbox-container.md`); `make` targets wrap every command.

## Layout

| Path | What |
|---|---|
| `ansible.cfg` | Settings (read through `ANSIBLE_CONFIG`, set in the toolbox) |
| `requirements.yml` | Collections, pinned; baked into the toolbox image |
| `inventories/local/` | The local server, a systemd container (`local/Dockerfile`, ADR-0007); the primary environment |
| `inventories/prod/` | Production; `hosts.yml` is generated from Terraform (Phase 5) |
| `playbooks/bootstrap.yml` | First login: creates the `deploy` user |
| `playbooks/site.yml` | Full host configuration and the application stack |
| `playbooks/verify.yml` | Read-only checks of the result |
| `playbooks/render-stack.yml` | Renders the stack without a host and validates it (CI) |
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
| [`stack`](roles/stack/README.md) | `stack` | postgres, migrate, api, worker, caddy with Compose; secrets from the vault |

## Secrets

Ansible Vault, `group_vars/all/vault.yml` per inventory. Production's is
encrypted and committed; the names are listed in
`inventories/prod/group_vars/all/vault.yml.example`. The local one is
generated with random values on first use and gitignored
(`docs/adr/0006-local-secrets-and-tls.md`). Every task that writes a secret
has `no_log: true`. Rotation: `docs/operations.md`.

## Local environment

```sh
make local-up            # server container up + bootstrap.yml (once) + site.yml
make local-check         # site.yml --check --diff
make local-idempotence   # site.yml again, fails unless changed=0
make local-verify        # no password/root login, ufw active, stack healthy, only 80/443 published
make local-smoke         # HTTPS smoke test through Caddy (from the workstation)
make local-scan          # port scan of the server (from another container)
make local-ssh           # shell on the server (deploy user, docker exec)
make local-halt          # stop the server
```

How the pieces connect:

1. `scripts/with-local-keys.sh` (in the toolbox) creates the `bootstrap`
   and `deploy` key pairs in `local/.ssh/` on first use (gitignored) and
   copies them to `/root/.ssh/uptime-local` with mode 0600: ssh refuses
   private keys that look world-readable, and on a Windows bind mount every
   file does. It also creates the local vault on first use and sets
   `ANSIBLE_VAULT_PASSWORD_FILE`.
2. `scripts/local-server.sh` (on the workstation) starts the server
   container `uptime-local` at `172.30.56.10` and installs the bootstrap
   key for root (ADR-0007). The toolbox joins the same Docker network.
3. `bootstrap.yml` logs in as `root`, creates `deploy` with the key and
   passwordless sudo.
4. `site.yml` logs in as `deploy` from then on; root is refused.

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
- `make test-ansible` runs Molecule: `site.yml` twice (including the
  stack), the second run must report `changed=0`, then `verify.yml`.
- `make test-compose` renders the stack for `local` and `prod` and
  validates it with `docker-compose config --quiet`.
