# Architecture decision records

One short file per decision: context → decision → alternatives →
consequences. A decision is never edited away: a later ADR supersedes it and
the old one gets `Status: superseded by NNNN`.

| ADR | Decision |
|---|---|
| [0001](0001-tooling-and-no-kubernetes.md) | Terraform + Ansible + Docker Compose, no Kubernetes |
| [0002](0002-toolbox-container.md) | All tooling runs in a pinned toolbox container |
| [0003](0003-local-only-environment.md) | Local-only environment; Terraform in validate-only mode |
