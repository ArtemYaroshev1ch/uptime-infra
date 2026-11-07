# 0003. Local-only environment; Terraform in validate-only mode

- Status: accepted; the "local Vagrant VM" part is superseded by
  [0007](0007-local-environment-in-a-container.md) (the local server is a
  systemd container)
- Date: 2026-11-06

## Context

The specification uses Hetzner Cloud as the production target. There is no
paid cloud account for this project, and the goal is to keep it free.
Free cloud tiers either have too little memory for the stack (1 GB machines:
the application, PostgreSQL, Prometheus, Loki and Grafana need about
2–3 GB) or are time-limited credits.

## Decision

- Every phase that needs a running host uses the **local Vagrant VM**
  (VirtualBox, Ubuntu LTS), configured by the same Ansible roles a cloud
  server would get. The `local` inventory is the primary environment.
- **Terraform runs in validate-only mode** (PROMPT.md §8): the `server` and
  `dns` modules and the `prod` environment are written as for a real
  deployment and pass `fmt`, `validate`, `tflint` and `trivy config` in CI,
  but `terraform apply` is never run.
- Hostnames use `sslip.io`-style names; locally Caddy uses its internal CA
  (`tls internal`) because Let's Encrypt cannot reach the VM.
- Off-host backups (Phase 7) go to a free S3-compatible bucket or, if none
  is available, to a MinIO container outside the VM; that choice gets its
  own ADR.

## Alternatives

- **Oracle Cloud Always Free (ARM, up to 24 GB RAM).** Free and large
  enough, and the application image is built for arm64. Needs a card for
  sign-up and has capacity limits in popular regions. The provider is
  isolated in the `server` module, so switching to it later only replaces
  that module; this is the preferred upgrade path.
- **Hetzner Cloud (about 5 EUR/month).** The specification's default; not
  free.
- **Free credits of AWS/GCP/Azure.** Time-limited and easy to overspend.

## Consequences

- The DoD items that need a public host are adapted: real Let's Encrypt
  certificates, external blackbox probes from the internet, and
  `terraform apply` / "No changes" are not demonstrated. Everything else
  (idempotent Ansible, the stack, alerts to Telegram, blue/green deploy,
  backups and restore verification, chaos experiments, the DR drill) runs
  against the VM.
- `deploy.yml` in GitHub Actions cannot reach the VM; deploys are run from
  the workstation with the same playbook, and the workflow is validated by
  actionlint only.
