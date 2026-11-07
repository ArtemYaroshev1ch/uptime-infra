# uptime-infra

[![CI](https://github.com/ArtemYaroshev1ch/uptime-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/ArtemYaroshev1ch/uptime-infra/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Infrastructure, observability and operations for
[uptime-monitor](https://github.com/ArtemYaroshev1ch/uptime-monitor): provision
a host with Terraform, configure it with Ansible, run the application and a
Prometheus/Grafana/Loki stack in Docker Compose, alert on SLO burn rate,
deploy blue/green with automatic rollback, and back up and verify restores.

> **Status: work in progress.** Phase 2 (the application stack). The project
> runs on a local server in a systemd container
> ([ADR-0007](docs/adr/0007-local-environment-in-a-container.md)); Terraform
> is kept in validate-only mode ([ADR-0003](docs/adr/0003-local-only-environment.md)).

## Repository layout

The target layout. Directories of later phases may be placeholders; what is
already implemented is listed in [What works today](#what-works-today).

| Path | What lives there |
|---|---|
| `terraform/` | Server and DNS modules, the `prod` environment (validate-only) |
| `ansible/` | Inventories, playbooks (`bootstrap`, `site`, `verify`; later `deploy`, `rollback`, `restore`) and roles |
| `observability/` | Prometheus rules and tests, Alertmanager, Grafana dashboards, Loki, Alloy, blackbox |
| `tools/restore-verifier/` | Go tool that restores the latest backup into a throwaway PostgreSQL and checks it |
| `scripts/` | Inventory generation, backup, smoke test, runbook coverage check |
| `runbooks/` | One runbook per alert |
| `chaos/` | Chaos experiment rules, template and records |
| `postmortems/` | Blameless postmortems |
| `local/` | Image of the local server (a systemd container) |
| `toolbox/` | Pinned container image in which every check runs |
| `docs/` | Architecture, operations, disaster recovery, ADRs |
| [`SLO.md`](SLO.md) | Service level objectives and the error budget policy |

## Quick start (local)

```sh
make local-up       # start the Ubuntu 26.04 server container, bootstrap it, apply site.yml
make local-verify   # ssh hardening, ufw, the stack healthy, only 80/443 published
make local-smoke    # HTTPS end to end: register, create a monitor, the worker checks it
make local-scan     # port scan of the server from another container
```

The application is at <https://app.127.0.0.1.sslip.io> (certificate
from Caddy's local CA: [`local/README.md`](local/README.md)). On the server:
base hardening (`common`, `ssh_hardening`, `firewall`, `fail2ban`), Docker
and the application stack (`stack`: PostgreSQL, migrations, API, worker,
Caddy); see [`ansible/README.md`](ansible/README.md).

## What works today

Done and merged (phases 1–2), each item with the place to check it:

| What | Where |
|---|---|
| Host hardening: ssh keys only, no root login, ufw, fail2ban | [`ansible/roles/`](ansible/roles/) (`common`, `ssh_hardening`, `firewall`, `fail2ban`) |
| App stack in Docker Compose: PostgreSQL, migrations before start, API, worker | [`ansible/roles/stack/`](ansible/roles/stack/README.md), [ADR-0005](docs/adr/0005-application-stack.md) |
| Caddy as the only published service (80/443), TLS, HSTS and security headers, `/metrics` not exposed | [`Caddyfile.j2`](ansible/roles/stack/templates/Caddyfile.j2) |
| Secrets in Ansible Vault; only an `*.example` is committed | [`vault.yml.example`](ansible/inventories/prod/group_vars/all/vault.yml.example), [ADR-0006](docs/adr/0006-local-secrets-and-tls.md) |
| Idempotence: `site.yml` twice in Molecule, second run `changed=0` | [ADR-0004](docs/adr/0004-ansible-idempotence-in-ci.md), `make test` |
| External port scan: only 22, 80 and 443 may answer | [`scripts/port-scan.sh`](scripts/port-scan.sh), `make local-scan` |
| HTTPS smoke test end to end (register, create a monitor, worker checks it) | [`scripts/smoke-test.sh`](scripts/smoke-test.sh), `make local-smoke` |

Not done yet: observability (Prometheus, Grafana, Loki, SLO alerts),
blue/green deploy with rollback, backups and restore verification, chaos
experiments. Directories for them in the layout above are the plan.

## Requirements

- Docker (Docker Desktop on Windows/macOS), GNU Make, Git. That is all:
  the local server is a container too.

Nothing else is installed on the host: Python, pre-commit, the linters,
Ansible and Molecule (later Terraform) run inside the toolbox container
([ADR-0002](docs/adr/0002-toolbox-container.md)).

## Development

```sh
make help      # list of targets
make lint      # every pre-commit hook on all files (incl. ansible-lint), inside the toolbox
make test      # Molecule (site.yml twice, changed=0) + render and validate the Compose stack
make secrets   # gitleaks over the whole git history
make shell     # a shell in the toolbox, e.g. for `pre-commit autoupdate`
```

On native Windows run `make` from PowerShell or Git Bash; recipes need
`C:\Program Files\Git\bin` in `PATH`.

## Decisions

Architecture decision records are in [`docs/adr/`](docs/adr/README.md).

## License

[MIT](LICENSE)
