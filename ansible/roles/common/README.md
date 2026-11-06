# common

Base configuration of every host.

- Points apt at the Ubuntu archives **over HTTPS**
  (`/etc/apt/sources.list.d/ubuntu.sources`). Packages are signed either
  way; HTTPS keeps the package list private and gets past middleboxes that
  stall large plain-HTTP downloads (the workstation's network cuts them at
  about 800 KB, which hung `apt upgrade` on the VM).
- Sets apt timeouts and retries (`/etc/apt/apt.conf.d/80-uptime-network`):
  a stalled mirror connection fails after 30 s and is retried instead of
  hanging the run (seen behind VirtualBox NAT).
- Refreshes the apt cache and upgrades installed packages (`upgrade: safe`).
  The upgrade runs **asynchronously** (`async` + `poll`): upgrading
  `openssh-server` stops sshd between unpack and configure, which would
  drop the ssh session a synchronous task runs in.
- Installs base tools (`common_packages`).
- Sets the timezone to UTC, so logs, metrics and timers agree.
- Enables `unattended-upgrades` for security updates. It never reboots the
  host by itself (`common_unattended_reboot: false`) and never upgrades the
  Docker packages, which the `docker` role pins.
- Templates the whole of `/etc/sysctl.d/60-uptime.conf` (a key removed from
  `common_sysctl` disappears from the host too) and applies it with
  `sysctl --system` when it changes.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `common_apt_mirror` | `https://archive.ubuntu.com/ubuntu` (arm64: ports) | Main archive |
| `common_apt_security_mirror` | `https://security.ubuntu.com/ubuntu` (arm64: ports) | Security archive |
| `common_apt_timeout` | `30` | Seconds before apt drops a silent connection |
| `common_apt_retries` | `5` | Retries of each apt download |
| `common_upgrade_packages` | `true` | Run `apt upgrade` (safe) on every run |
| `common_upgrade_timeout` | `3600` | Longest the upgrade may run, seconds |
| `common_packages` | see `defaults/main.yml` | Packages to install |
| `common_timezone` | `Etc/UTC` | System timezone |
| `common_unattended_reboot` | `false` | Let unattended-upgrades reboot the host |
| `common_sysctl` | see `defaults/main.yml` | Kernel parameters |
| `common_sysctl_apply` | `true` | Apply them to the running kernel (Molecule: `false`) |

## Notes

- `upgrade: safe` changes something only when the mirror has new updates,
  so the second run of the same playbook reports `changed=0`.
- `net.ipv4.ip_forward` is not touched: Docker enables it for its bridges.
- `net.ipv4.conf.all.log_martians` is not touched either: ufw sets it from
  `/etc/ufw/sysctl.conf` on every start. Two owners of one value make every
  run report a change; `make local-idempotence` caught exactly that.
