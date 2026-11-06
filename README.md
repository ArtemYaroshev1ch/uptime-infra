# uptime-infra

[![CI](https://github.com/ArtemYaroshev1ch/uptime-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/ArtemYaroshev1ch/uptime-infra/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Infrastructure, observability and operations for
[uptime-monitor](https://github.com/ArtemYaroshev1ch/uptime-monitor): provision
a host with Terraform, configure it with Ansible, run the application and a
Prometheus/Grafana/Loki stack in Docker Compose, alert on SLO burn rate,
deploy blue/green with automatic rollback, and back up and verify restores.

> **Status: work in progress.** Phase 0 (repository skeleton). The project
> runs on a local Vagrant VM; Terraform is kept in validate-only mode
> ([ADR-0003](docs/adr/0003-local-only-environment.md)).

## Repository layout

| Path | What lives there |
|---|---|
| `terraform/` | Server and DNS modules, the `prod` environment (validate-only) |
| `ansible/` | Inventories, playbooks (`bootstrap`, `site`, `deploy`, `rollback`, `restore`) and roles |
| `observability/` | Prometheus rules and tests, Alertmanager, Grafana dashboards, Loki, Alloy, blackbox |
| `tools/restore-verifier/` | Go tool that restores the latest backup into a throwaway PostgreSQL and checks it |
| `scripts/` | Inventory generation, backup, smoke test, runbook coverage check |
| `runbooks/` | One runbook per alert |
| `chaos/` | Chaos experiment rules, template and records |
| `postmortems/` | Blameless postmortems |
| `local/` | Vagrantfile of the local environment |
| `toolbox/` | Pinned container image in which every check runs |
| `docs/` | Architecture, operations, disaster recovery, ADRs |
| [`SLO.md`](SLO.md) | Service level objectives and the error budget policy |

## Requirements

- Docker (Docker Desktop on Windows/macOS), GNU Make, Git.
- Phase 1 onwards: VirtualBox and Vagrant for the local environment.

Nothing else is installed on the host: Python, pre-commit, the linters and,
later, Ansible and Terraform run inside the toolbox container
([ADR-0002](docs/adr/0002-toolbox-container.md)).

## Development

```sh
make help      # list of targets
make lint      # every pre-commit hook on all files, inside the toolbox
make secrets   # gitleaks over the whole git history
make shell     # a shell in the toolbox, e.g. for `pre-commit autoupdate`
```

On native Windows run `make` from PowerShell or Git Bash; recipes need
`C:\Program Files\Git\bin` in `PATH`.

## Decisions

Architecture decision records are in [`docs/adr/`](docs/adr/README.md).

## License

[MIT](LICENSE)
