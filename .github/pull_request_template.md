## What and why

<!-- What changes and why. Link the issue or the PROMPT.md phase. -->

## Plan / diff

<!-- terraform plan, ansible-playbook --check --diff, or the rendered config diff. -->

## Rollback plan

<!-- How to undo this change if it goes wrong. -->

## Checklist

- [ ] `make lint test` passes locally
- [ ] The plan or diff is attached (Terraform, Ansible `--check --diff`)
- [ ] Idempotent: a second run shows `changed=0` / "No changes"
- [ ] There is a rollback plan
- [ ] New alerts have runbooks; new roles have a README; new decisions have an ADR
- [ ] No secrets in the diff or in the output (only `*.example`)
- [ ] Image tags, providers and collections are pinned (no `latest`)
