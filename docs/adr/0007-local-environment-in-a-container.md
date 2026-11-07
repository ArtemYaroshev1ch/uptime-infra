# 0007. The local server is a systemd container, not a VirtualBox VM

- Status: accepted
- Date: 2026-11-07
- Supersedes: the "local Vagrant VM" part of ADR-0003 (the rest of 0003,
  local-only and Terraform validate-only, stands)

## Context

ADR-0003 made a Vagrant/VirtualBox VM the local environment. On the
workstation (Windows 11 Home, 7.4 GB RAM) Docker Desktop needs Hyper-V, so
VirtualBox runs on top of it (NEM) and its guest memory is ordinary,
pageable process memory. In Phase 2, with Docker Desktop, the 2 GB guest
and the usual desktop programs, the commit charge reached 14.6 of 16 GB:

- Windows paged the guest out (`VBoxHeadless` working set 12 MB of 2 GB);
- `VBox.log` reported the guest unresponsive for up to 189 s at a time
  (`TM: Giving up catch-up ... lag 1 347 s` in total);
- Ansible runs failed as unreachable, `vagrant up` hit its boot timeout,
  and the Phase 2 checks could not be repeated.

Phase 3 adds Prometheus, Grafana, Loki and exporters, so this only gets
worse. Two virtualisation layers with two fixed memory reservations do not
fit on this machine.

Molecule (ADR-0004) already runs `site.yml`, including the stack, in a
privileged Ubuntu 26.04 container with systemd as PID 1: ufw, fail2ban,
sshd and a Docker engine all work there.

## Decision

- The local "server" is **one privileged container** `uptime-local` built
  from `local/Dockerfile` (Ubuntu 26.04, systemd, sshd, python3), run by
  `scripts/local-server.sh` on Docker Desktop:
  - its own Docker network `uptime-local` (`172.30.56.0/24`), fixed
    address `172.30.56.10`;
  - `/var/lib/docker` and `/var/lib/containerd` in named volumes (images
    and the database survive `make local-halt`);
  - Caddy's 80/443 published on the workstation's `127.0.0.1` only; the
    application is `https://app.127.0.0.1.sslip.io`.
- **Ansible connects over real ssh**, from the toolbox container attached
  to the same network, exactly as to a cloud host: `bootstrap.yml` logs in
  as **root** with a bootstrap key (installed by `local-server.sh` while no
  `deploy` user exists, like a cloud provider does), then everything runs
  as `deploy` and `ssh_hardening` forbids root. The refused password and
  root logins in `verify.yml` are real ssh attempts.
- **The port scan runs from another container** on that network (the
  toolbox): a different network namespace, so it sees what an outside
  machine sees, including Docker's iptables rules that bypass ufw.
- **Molecule builds the same `local/Dockerfile`**: CI tests the machine the
  operator runs. The difference is the connection (Molecule uses the
  Docker API, so its login checks are skipped).
- Kernel settings are written but not applied (`common_sysctl_apply:
  false`), as in Molecule: the container shares Docker Desktop's kernel.
- `local/Vagrantfile` is removed. Docker Desktop's memory limit
  (`%USERPROFILE%\.wslconfig`) is now the only budget to tune.

## Alternatives

- **Keep the VM, give it less memory or close programs.** Treats the
  symptom; Phase 3 needs more memory, not less.
- **VirtualBox without Docker Desktop.** Docker is needed for the toolbox
  and every check (ADR-0002).
- **Hyper-V VM instead of VirtualBox.** Not available on Windows Home.
- **WSL 2 distribution as the server.** No systemd-managed sshd/ufw by
  default, shares the WSL VM with Docker Desktop anyway, and is less like a
  server than a container built from a cloud-like image.
- **Only Molecule, no persistent local server.** Loses the long-running
  environment that Phases 3–9 observe, deploy to, back up and break.

## Consequences

- One memory budget (Docker Desktop's) instead of two; nothing is
  reserved up front. Phase 3 raises `memory=` in `.wslconfig`.
- Not tested locally any more: the kernel the roles run on (it is Docker
  Desktop's, not Ubuntu's), applied sysctls, reboots after kernel updates,
  the boot sequence of a real VM. Production (Phase 5) or a cloud VM is
  where those would be checked.
- ufw and Docker's iptables rules act inside the container's network
  namespace, which is what the scan tests; Docker Desktop's own port
  forwarding to `127.0.0.1` sits outside it.
- `make local-destroy` removes the container **and its volumes** (the
  database); never run without an explicit request (CLAUDE.md).
