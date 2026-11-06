# 0001. Tooling: Terraform + Ansible + Docker Compose, no Kubernetes

- Status: accepted
- Date: 2026-11-06

## Context

`uptime-monitor` is a small service: one stateless API, a worker that is safe
to run in N copies, and PostgreSQL. This repository has to provision a server,
configure it, run the application with a full observability stack, deploy new
versions without downtime, back up and restore the database, and be a
learning ground for SRE practices (SLOs, burn-rate alerts, chaos, DR).

The tools have to be industry-standard, cheap to run (a single small VM), and
small enough that every moving part can be understood end to end.

## Decision

- **Terraform** (OpenTofu-compatible) describes the infrastructure: VM,
  firewall, DNS. Declarative, with a plan before every change.
- **Ansible** configures the host and the stack: agentless (SSH only),
  idempotent roles, Ansible Vault for secrets.
- **Docker Engine + Compose v2** runs the application and the observability
  stack on a single host. The same Compose template runs on the local VM and
  on a server.
- **Caddy** terminates HTTPS and switches between the blue and green API.
- **Prometheus, Alertmanager, Grafana, Loki, Grafana Alloy** for metrics,
  alerts, dashboards and logs, all provisioned from files in this repository.
- **GitHub Actions** for CI and for the manual-approval deploy.

## Alternatives

- **Kubernetes (k3s, managed clusters).** Gives rolling updates, self-healing
  and service discovery out of the box, but on one small node it costs more
  memory than the whole application, hides the mechanics this project wants
  to learn (blue/green, health-gated switching, rollback), and adds a large
  surface (CNI, ingress, CSI, RBAC) to operate. Revisit when there is more
  than one node or more than one team; listed as a stretch goal in a separate
  repository.
- **Docker Swarm / Nomad.** Smaller than Kubernetes, but still an orchestrator
  for a single host, with a much smaller ecosystem and job market.
- **Pulumi / CDK instead of Terraform.** Real programming languages, but
  Terraform's HCL and plan workflow are the common denominator in SRE roles.
- **Shell scripts or cloud-init only instead of Ansible.** Simpler at first,
  but not idempotent by construction and hard to test for `changed=0`.

## Consequences

- One host is a single point of failure; the availability SLO (99.5 %) and
  the DR procedure are sized for that.
- Blue/green, rollback and health gating are implemented by hand in the
  `deploy` role, which is the point of the exercise.
