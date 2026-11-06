# fail2ban

Bans addresses that keep failing ssh logins.

- Jail `sshd`, reading sshd's messages from the systemd journal
  (`backend = systemd`; Ubuntu servers have no `/var/log/auth.log`).
- 5 failures in 10 minutes → 1 hour ban; repeat offenders get doubled bans
  up to a week (`bantime.increment`).
- Settings live in `/etc/fail2ban/jail.d/sshd.local`; the packaged
  `jail.conf` stays untouched.

With key-only ssh a brute force cannot succeed anyway; fail2ban removes the
noise from the logs and the load of thousands of attempts, and is one more
layer if a weak key or a misconfiguration ever slips in.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `fail2ban_maxretry` | `5` | Failures before a ban |
| `fail2ban_findtime` | `10m` | Window in which failures are counted |
| `fail2ban_bantime` | `1h` | First ban |
| `fail2ban_bantime_increment` | `true` | Grow bans for repeat offenders |
| `fail2ban_bantime_maxtime` | `1w` | Longest ban |
| `fail2ban_ignoreip` | `[]` | Never banned (loopback is always added) |
| `fail2ban_ssh_port` | `22` | Must match `ssh_hardening_port` |

## Operations

```sh
sudo fail2ban-client status sshd             # banned addresses
sudo fail2ban-client set sshd unbanip <ip>   # lift a ban
```
