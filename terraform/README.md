# terraform

Infrastructure as code (Phase 5): reusable modules in `modules/` (`server`:
VM, SSH key, firewall; `dns`: optional records) and the `prod` environment
in `envs/prod/`. Runs in validate-only mode, see
[ADR-0003](../docs/adr/0003-local-only-environment.md).
