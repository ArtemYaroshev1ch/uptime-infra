# Architecture decision records

One short file per decision: context → decision → alternatives →
consequences. A decision is never edited away: a later ADR supersedes it and
the old one gets `Status: superseded by NNNN`.

| ADR | Decision |
|---|---|
| [0001](0001-tooling-and-no-kubernetes.md) | Terraform + Ansible + Docker Compose, no Kubernetes |
| [0002](0002-toolbox-container.md) | All tooling runs in a pinned toolbox container |
| [0003](0003-local-only-environment.md) | Local-only environment; Terraform in validate-only mode (VM part superseded by 0007) |
| [0004](0004-ansible-idempotence-in-ci.md) | Ansible idempotence is tested with Molecule in a systemd container |
| [0005](0005-application-stack.md) | Application stack: one Compose project, migrations outside `up`, least privilege |
| [0006](0006-local-secrets-and-tls.md) | Local environment: generated vault, sslip.io and Caddy's own CA |
| [0007](0007-local-environment-in-a-container.md) | The local server is a systemd container, not a VirtualBox VM |
