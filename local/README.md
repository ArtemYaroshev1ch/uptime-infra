# local

The local environment (`docs/adr/0003-local-only-environment.md`,
`docs/adr/0007-local-environment-in-a-container.md`): one Ubuntu 26.04
"server" as a privileged container with systemd, sshd and its own Docker
engine, configured by the same Ansible roles as a cloud server.

| | |
|---|---|
| Image | `local/Dockerfile` (`ubuntu:resolute-20261024.1`, systemd, sshd, python3); Molecule builds the same file |
| Container | `uptime-local`, network `uptime-local` (`172.30.56.0/24`), address `172.30.56.10` |
| Data | volumes `uptime-local-docker` and `uptime-local-containerd` (images, the database) |
| Published | Caddy's 80 and 443 on `127.0.0.1` only |
| Accounts | `root` (bootstrap key, refused after `site.yml`), `deploy` (Ansible) |
| Memory | Docker Desktop's limit in `%USERPROFILE%\.wslconfig` |

```sh
make local-up       # build/create/start + bootstrap (once) + site
make local-verify   # ssh hardening, ufw, the stack healthy, only 80/443 published
make local-smoke    # HTTPS smoke test from the workstation
make local-scan     # port scan from another container: only 22, 80, 443 answer
make local-ssh      # shell as deploy (docker exec, not ssh)
make local-halt     # stop; `make local-up` starts it again
```

`make local-destroy` removes the container, its volumes (the database) and
the network.

How it fits together:

1. `scripts/with-local-keys.sh` (in the toolbox) creates two key pairs in
   `local/.ssh/` (gitignored): `bootstrap` and `deploy`.
2. `scripts/local-server.sh up` (on the workstation) builds the image,
   starts the container and, while there is no `deploy` user, puts the
   bootstrap key into root's `authorized_keys`, as a cloud provider would.
3. `bootstrap.yml` logs in as root over ssh and creates `deploy`.
4. `site.yml` runs as `deploy`; `ssh_hardening` forbids root from then on.

Ansible and the port scan run in the toolbox container attached to the
`uptime-local` network: a separate machine as far as the server's ufw and
Docker's iptables rules are concerned.

## The application in the browser

<https://app.127.0.0.1.sslip.io>: sslip.io resolves the name to
`127.0.0.1`, where Caddy is published, and Caddy serves it with a
certificate from its own local CA (`docs/adr/0006-local-secrets-and-tls.md`).
The browser warns until it trusts that CA:

1. `make local-ca` copies the root certificate to `local/caddy-root.crt`.
2. Optional: import it for the current user only, so it can be removed
   again easily: `certutil -user -addstore Root local\caddy-root.crt`
   (remove: `certmgr.msc` → Trusted Root → "Caddy Local Authority").
   Anyone with the CA key on the server could then issue certificates your
   browser trusts, so remove it when you destroy the server.

If the name does not resolve (some routers block DNS answers with loopback
addresses), add `127.0.0.1 app.127.0.0.1.sslip.io` to
`C:\Windows\System32\drivers\etc\hosts`.

## Secrets

`local/.vault-pass` and `ansible/inventories/local/group_vars/all/vault.yml`
are created on first use with random values and are gitignored. Keep them
as long as the server exists: Postgres was initialised with that password.

## Differences from a real server

- The kernel is Docker Desktop's: `sysctl` settings are written but not
  applied (`common_sysctl_apply: false`), kernel updates do nothing until
  Docker Desktop updates, and there is no reboot.
- `systemd-modules-load`, `systemd-logind` and the consoles are masked:
  they cannot work in a container.

## Known issues (Windows workstation)

- **Memory.** The workstation has 7.4 GB. Until Phase 2 the local server
  was a VirtualBox VM on top of Hyper-V; Windows paged its memory out
  under pressure and the guest stalled for minutes (ADR-0007). Now the
  only budget is Docker Desktop's (`[wsl2] memory=` in `.wslconfig`, then
  `wsl --shutdown` and restart Docker Desktop).
- **Large plain-HTTP downloads stall** on this network at about 800 KB,
  while HTTPS is fast. The `common` role therefore uses the Ubuntu archives
  over HTTPS, and apt has timeouts and retries. A stalled `apt upgrade`
  leaves broken partial files in `/var/cache/apt/archives/partial/`;
  delete them before retrying.
- **Git Bash rewrites Unix-looking arguments** (`/sys/fs/cgroup`,
  `/repo`) into Windows paths before they reach `docker.exe`; the Makefile
  and `scripts/local-server.sh` set `MSYS_NO_PATHCONV=1`.
