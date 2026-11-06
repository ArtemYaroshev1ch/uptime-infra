# firewall

Host firewall with `ufw`: incoming traffic is denied by default, except

- ssh (`limit`: an address that opens 6+ connections in 30 s is refused),
  from `firewall_ssh_sources`;
- TCP 80 and 443 (Caddy).

Outgoing traffic is allowed. The ssh rule is added before `ufw` is
enabled, so the run never cuts its own connection.

In production this is the second layer behind the cloud firewall
(Terraform): defense in depth, one misconfigured layer does not expose the
host.

## Docker bypasses ufw

Ports **published** by Docker (`ports:` in Compose) are opened by Docker's
own iptables rules, which are evaluated before ufw's. ufw does not protect
them. That is why the stack publishes only Caddy's 80/443 and keeps every
other service (PostgreSQL, Prometheus, ops ports) on internal Docker
networks without published ports; Phase 2 checks it with a port scan.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `firewall_ssh_sources` | `[any]` | Addresses allowed to reach ssh |
| `firewall_public_tcp_ports` | `[80, 443]` | Public TCP ports |
| `firewall_logging` | `low` | ufw logging level |
| `firewall_ssh_port` | `22` | Must match `ssh_hardening_port` |
