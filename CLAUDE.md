# CLAUDE.md

Working context for AI assistants in this repository. The full specification
is `PROMPT.md`; this file is a digest of its sections 2, 3 and 4 plus the
local environment and the decisions that adapt the specification. If they
disagree, `PROMPT.md` wins, except where an ADR in `docs/adr/` says
otherwise.

`uptime-infra` deploys, observes, protects, updates, restores and breaks the
application [`uptime-monitor`](../uptime-monitor) (sibling repository
`D:\projects\uptime-monitor`, released as `1.0.0`). Main SRE portfolio repo.

## Working rules (PROMPT.md §2)

1. Work in phases (PROMPT.md §19). Do not start the next phase until the
   current one meets its Definition of Done.
2. At the start of a phase print a short plan (5–10 lines). At the end run
   `make lint test` plus the phase's own checks, show the result, list the
   commits and **stop and wait for the user's confirmation**. Also give a
   5–10 line explanation of key decisions ("why", especially SRE concepts)
   and name 2–3 places worth studying.
3. Git: one phase = branch `feat/phase-N-<slug>`. Small commits, Conventional
   Commits in English (`feat(ansible): add ssh hardening role`). Commit
   locally. **No `git push`, no PRs, no `--force` without an explicit
   command.** Never `git commit -a`: the user edits files during sessions.
4. Everything idempotent: a second Ansible run gives `changed=0`, a second
   `terraform plan` gives "No changes".
5. No secrets in the repository **or in the output**: Ansible Vault / GitHub
   Secrets; only `*.example` files. Never print vault contents, `*.tfvars`,
   `.env`.
6. Versions pinned: image tags (never `latest`), Terraform providers with
   constraints and a committed `.terraform.lock.hcl`, Ansible collections in
   `requirements.yml`, pre-commit hook revs, toolbox packages. Check current
   versions, do not rely on memory.
7. Language: code, comments, commits, README, ADRs, runbooks in English.
   Talk to the user in Russian.
8. Every infrastructure change goes through branch → CI → review → merge.
9. Documentation is part of the work: an alert without a runbook, a role
   without a README, a decision without an ADR is unfinished.

Ambiguous requirement → pick the simplest reasonable option and record a
short ADR in `docs/adr/` (context → decision → alternatives → consequences).

## Safety (PROMPT.md §3) — critical

- **Never run without an explicit command from the user in the chat:**
  `terraform apply`, `terraform destroy`, `ansible-playbook` against `prod`,
  `vagrant destroy`, `docker system prune`, `rm -rf` outside the working
  directory, deleting or overwriting volumes and databases.
- Default to safe modes: `terraform fmt/validate/plan`,
  `ansible-playbook --check --diff`, `ansible-lint`, `promtool`,
  `docker compose config` (with `--quiet` when it would print secrets).
- Before creating any cloud resource, estimate the monthly cost and show it.
- Every cloud resource is labelled `project=uptime`.
- A secret in a commit or in output → **stop and tell the user** (rotate,
  clean history).
- Destructive data operations (restore over a live DB, deleting a volume)
  only after a verified backup and the user's confirmation.

## Contract with `uptime-monitor` (PROMPT.md §4)

Source of truth: §3 of `uptime-monitor`'s `PROMPT.md` and its
`docs/metrics.md`.

| Area | What the infrastructure relies on |
|---|---|
| Image | `ghcr.io/artemyaroshev1ch/uptime-monitor:<semver>` (no `v`), `linux/amd64` + `linux/arm64`; `/app/api`, `/app/worker`, `/app/migrate`; distroless, no shell, non-root |
| Ports | `api` 8080 (public), 9090 (ops: `/metrics`); `worker` 9091 (`/healthz`, `/readyz`, `/metrics`). Ops ports never published |
| Probes | `/healthz` liveness (no DB), `/readyz` readiness (DB; worker also scheduler heartbeat < 30 s) |
| Healthcheck | `api -healthcheck`, `worker -healthcheck` (exit 0/1) |
| Migrations | `/app/migrate up` **before** the new version starts; backward compatible → image rollback is safe |
| Shutdown | SIGTERM, graceful ≤ 25 s → `stop_grace_period: 30s` |
| Scaling | `api` stateless; `worker` safe in N copies (`SKIP LOCKED`) → blue/green without downtime |
| Metrics | prefix `uptime_`, catalog in `docs/metrics.md`; **no** per-monitor labels |
| Logs | JSON to stdout (`time`, `level`, `msg`, `service`, `version`, `request_id`, ...) |
| Config | env only (`DATABASE_URL`, `JWT_SECRET`, `TELEGRAM_BOT_TOKEN`, ...) |
| Version | `GET /version` → `{"version","commit","built_at"}` |

The production app version is the single variable `app_version` in
`ansible/inventories/prod/group_vars/all/vars.yml`.

## Adaptations of the specification (ADRs)

- **0002 — toolbox container.** Every check (pre-commit, linters, later
  Ansible, Terraform, promtool) runs in `toolbox/Dockerfile` via `make`;
  CI calls the same targets. Add new tools to the toolbox, not to the host.
- **0003 — local only.** No cloud account: the Vagrant VM (`local`
  inventory) is the primary environment; Terraform is validate-only (never
  `apply`); Caddy uses `tls internal` locally.
- **0005 — stack.** One Compose project `uptime` in `/opt/uptime`;
  `migrate` runs via `docker compose run` before `up` (idempotence); only
  Caddy publishes ports; no root in any container.
- **0006 — local secrets/TLS.** Local vault is generated and gitignored
  (`local/.vault-pass`); app at `https://app.192.168.56.10.sslip.io`, CA
  root via `make local-ca`.

## Make targets

`make help` for the current list. Now: `help`, `toolbox`, `shell`, `lint`
(`pre-commit run --all-files` in the toolbox, includes `ansible-lint`
production profile), `test` (= `test-ansible`: Molecule idempotence test
incl. the stack, ADR-0004; + `test-compose`: render and
`docker-compose config --quiet`), `secrets` (gitleaks over the history),
and the local VM: `local-up`, `local-bootstrap`, `local-site`,
`local-check`, `local-idempotence`, `local-verify`, `local-ca`,
`local-smoke` (HTTPS smoke test from the host), `local-scan` (port scan
from the host), `local-ssh`, `local-halt`, `local-destroy` (never without
an explicit request). `make lint test` is the phase gate.

## Environment

- Windows 11 Home, native, **no WSL**, no Python on the host. Project at
  `D:\projects\uptime-infra`.
- Docker Desktop (must be running for every check). VirtualBox + Vagrant
  are needed from Phase 1 (Hyper-V provider is unavailable on Home).
- Git for Windows; `C:\Program Files\Git\bin` is in PATH, `usr\bin` is not.
  `core.autocrlf=true` system-wide, so `.gitattributes` forces LF.
- GNU Make (ezwinports) runs recipes through Git's `sh`; the Makefile adds
  Git's `/usr/bin` to PATH and sets `MSYS_NO_PATHCONV=1` on Windows.
- Local VM: `bento/ubuntu-26.04` at `192.168.56.10` (host-only). Docker
  Desktop containers **cannot** reach the host-only network, so Ansible in
  the toolbox connects via Vagrant's forward `host.docker.internal:2222`;
  the browser on Windows uses `192.168.56.10`. ssh keys: `local/.ssh/`
  (gitignored), copied with mode 0600 by `scripts/with-local-keys.sh`.
- Go 1.27 is installed (for `tools/restore-verifier` in Phase 7).
- Host RAM is 7.4 GB and tight: Docker Desktop is capped at 2 GB in
  `%USERPROFILE%\.wslconfig`; Vagrant boxes and VMs live on `D:\DevData`
  (`VAGRANT_HOME`, VirtualBox machine folder). Keep downloads off `C:`.
- Bash heredocs with unbalanced apostrophes fail in the assistant's shell:
  write files with the editor tools. No `sed` on markdown tables with `|`.
