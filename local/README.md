# local

The local environment (`docs/adr/0003-local-only-environment.md`): one
Ubuntu 26.04 LTS VM, configured by the same Ansible roles as a server.

| | |
|---|---|
| Box | `bento/ubuntu-26.04` `202606.01.0` (pinned), VirtualBox |
| Address | `192.168.56.10` (host-only network) |
| Size | 2 CPUs, 2 GB RAM (the workstation has 7.4 GB; Phase 3 revisits it) |
| Accounts | `vagrant` (Vagrant's own), `deploy` (Ansible, created by `bootstrap.yml`) |

Vagrant only creates the VM; it shares no folder and runs no provisioner.
Ansible configures it from the toolbox container, as it would a cloud
host:

```sh
make local-up       # create/start + bootstrap + site
make local-verify   # check the result
make local-smoke    # HTTPS smoke test of the application
make local-scan     # only 22, 80, 443 answer
make local-halt     # stop
```

## The application in the browser

<https://app.192.168.56.10.sslip.io>: sslip.io resolves the name to the
VM, Caddy serves it with a certificate from its own local CA
(`docs/adr/0006-local-secrets-and-tls.md`). The browser warns until it
trusts that CA:

1. `make local-ca` copies the root certificate to `local/caddy-root.crt`.
2. Optional: import it for the current user only, so it can be removed
   again easily: `certutil -user -addstore Root local\caddy-root.crt`
   (remove: `certmgr.msc` → Trusted Root → "Caddy Local Authority").
   Anyone with the CA key on the VM could then issue certificates your
   browser trusts, so remove it when you destroy the VM.

If the name does not resolve (some routers block DNS answers with private
addresses), add `192.168.56.10 app.192.168.56.10.sslip.io` to
`C:\Windows\System32\drivers\etc\hosts`.

## Secrets

`local/.vault-pass` and `ansible/inventories/local/group_vars/all/vault.yml`
are created on first use with random values and are gitignored. Keep them
as long as the VM exists: Postgres was initialised with that password.

`make local-destroy` deletes the VM and its disk.

Requirements: VirtualBox 7.x and Vagrant 2.4+ on the host, Docker for the
toolbox. On Windows the host-only network `192.168.56.0/24` is created by
VirtualBox automatically.

## Known issues (Windows workstation)

Found while building Phase 1; each one cost a failed run.

- **Docker containers cannot reach the host-only network.** Ansible runs in
  the toolbox container, so the inventory uses Vagrant's port forward
  `host.docker.internal:2222` instead of `192.168.56.10`. Inside the VM all
  of these connections come from the NAT gateway `10.0.2.2`, which is why
  it is in `fail2ban_ignoreip`.
- **VirtualBox runs on top of Hyper-V** (Docker Desktop enables it; the
  VM log says `Attempting fall back to NEM`). It works, but slower, and a
  guest that does not fit into free host memory stalls completely (kernel
  "rcu_preempt ... starved" messages on the console, ssh refused). Keep the
  VM at 2 GB on a 7–8 GB machine, or cap Docker Desktop's memory in
  `%USERPROFILE%\.wslconfig`.
  Seen again in Phase 2 with the host's commit charge at 14.6 of 16 GB:
  Windows paged the whole guest out (`VBoxHeadless` working set 12 MB,
  `Guest seems to be unresponsive` in `VBox.log`, load average 59 inside
  an idle guest) and Ansible runs failed as unreachable. What helped:
  `[wsl2] memory=2GB` in `.wslconfig` (then `wsl --shutdown` and restart
  Docker Desktop), closing other large programs, and `vagrant halt` +
  `vagrant up` for a guest that does not come back.
- **Large plain-HTTP downloads stall** on this network at about 800 KB (both
  in the VM and on Windows itself), while HTTPS is fast. The `common` role
  therefore uses the Ubuntu archives over HTTPS, and apt has timeouts and
  retries. A stalled `apt upgrade` leaves broken partial files in
  `/var/cache/apt/archives/partial/`; delete them before retrying.
- **The first boot after a hang can exceed Vagrant's boot timeout.** If
  `vagrant up` reports that it could not connect, check `vagrant status`
  and `vagrant ssh`: the VM is usually up a minute later.
