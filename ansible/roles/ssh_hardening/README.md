# ssh_hardening

Locks down the OpenSSH server without locking the operator out.

- Public keys only: password and keyboard-interactive logins are off,
  `root` cannot log in.
- `AllowUsers` lists the only accounts that may log in
  (`ssh_hardening_allowed_users`).
- Modern key exchange, ciphers and MACs; agent, X11 and remote forwarding
  off. Local forwarding stays on for admin tunnels (`ssh -L 9090:...`).
- `LogLevel VERBOSE` logs the fingerprint of the key used for each login.

## How it avoids a lockout

1. The role refuses to run when `ssh_hardening_allowed_users` is empty or does not
   contain the account Ansible connects as.
2. The settings go into one drop-in, `sshd_config.d/00-uptime-hardening.conf`.
   The template is validated with `sshd -t -f <new file>` before it
   replaces the old file, so a file with a typo or an unknown algorithm
   never lands.
3. `sshd -t` then checks the whole effective configuration. If it fails,
   the play stops before the handler, and the running sshd keeps serving
   the configuration it has loaded.
4. The handler **reloads** sshd instead of restarting it: existing sessions,
   including Ansible's own, stay open. If the new rules were wrong, the open
   session is still there to fix them.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `ssh_hardening_allowed_users` | `[]` (must be set) | Accounts allowed to log in |
| `ssh_hardening_port` | `22` | Listening port |
| `ssh_hardening_allow_tcp_forwarding` | `local` | `ssh -L` tunnels only |
| `ssh_hardening_max_auth_tries` | `3` | Attempts per connection |
| `ssh_hardening_login_grace_time` | `30s` | Time to authenticate |
| `ssh_hardening_client_alive_interval`, `ssh_hardening_client_alive_count_max` | `300`, `2` | Drop dead sessions |
| `ssh_hardening_kex_algorithms`, `ssh_hardening_ciphers`, `ssh_hardening_macs`, `ssh_hardening_host_key_algorithms` | see defaults | Allowed algorithms |

## Check

`make local-verify` tries a password login and a root login against the
local server over real ssh and expects both to be refused; `sshd -T` shows
the effective settings.
