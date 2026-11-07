# 0005. Application stack: one Compose project, migrations outside `up`

- Status: accepted
- Date: 2026-11-07

## Context

Phase 2 runs `uptime-monitor` on the host: PostgreSQL, the one-shot
migrations, the API, the worker and Caddy in front (PROMPT.md §10). The
stack must be started by Ansible, so a second `site.yml` run has to report
`changed=0` (PROMPT.md §2, ADR-0004). Phase 6 adds blue/green deploys of
the API on top of it.

Three facts shaped the design:

1. `docker compose up` starts a **finished one-shot container again** on
   every run (checked with Compose 5.7: `migrate Starting → Started →
   Exited`). With `migrate` as a normal service with
   `service_completed_successfully`, `community.docker.docker_compose_v2`
   reports a change on every run, and idempotence is lost.
2. A published container port gets **Docker's own iptables rules**, which
   are evaluated before ufw's. `ufw default deny` does not protect a
   published Postgres port.
3. The official Caddy and Postgres images start as root.

## Decision

- **One Compose project** `uptime` in `/opt/uptime`, rendered by the
  `stack` role from a Jinja template: `compose.yml`, `env/*.env` (secrets,
  mode 0600, root only, `no_log`), `caddy/etc/Caddyfile`.
- **Order in the role:** start `postgres` (wait for healthy) →
  `docker compose run --rm migrate` → `up --wait` for everything else. The
  `migrate` service sits in the `tools` profile, so `up` never starts it.
  The task reports `changed` only when the JSON log line of the migrate
  command does not say `"applied":0`. A failed migration stops the run
  before any application container is replaced (same order as the deploy
  in PROMPT.md §14, step 4).
- **Networks:** `edge` (caddy, api) and `backend` (api, worker, postgres,
  migrate). Only caddy publishes ports: 80, 443/tcp and 443/udp (HTTP/3).
  `verify.yml` asserts that no container on the host publishes anything
  else, and `scripts/port-scan.sh` proves it from another machine.
- **API colors from day one:** the template renders an `api-<color>`
  service for every entry of `stack_api_colors` with a version, and Caddy
  proxies to `stack_active_color`. Phase 2 runs only `api-blue`; Phase 6
  switches colors without renaming services.
- **Least privilege for every container:** `cap_drop: [ALL]`,
  `no-new-privileges`, `read_only` root filesystem with `tmpfs` where
  needed, and no root:
  - app images: uid 65532 (distroless);
  - postgres: `user: 70:70`, the image's own `postgres` user, which owns
    the data directory in the image;
  - caddy: `user: 65532:65532`, with the namespaced sysctl
    `net.ipv4.ip_unprivileged_port_start=0` instead of
    `CAP_NET_BIND_SERVICE` (a file capability would be ignored under
    `no-new-privileges` anyway). Its data lives in bind mounts owned by
    65532, because a named volume would be created root-owned.
- **Caddy's config directory, not the file, is mounted:** Ansible replaces
  the Caddyfile atomically (new inode), which a single-file bind mount
  would never see. A handler runs `caddy reload` (graceful; a bad config is
  rejected and the old one stays).
- **Tests:** CI renders the template for `local` and `prod` and runs
  `docker-compose config --quiet` (`make test-compose`, job `compose`).
  Molecule (ADR-0004) also runs the role, so the stack's idempotence is
  checked in CI; throwaway values replace the vault there.

## Alternatives

- **`migrate` as a regular service with `service_completed_successfully`**
  (the specification's table). Simplest, but breaks idempotence (fact 1);
  the dependency semantics are kept by running it before `up`.
- **Always report `changed: false` for migrations.** Idempotent on paper,
  but hides real schema changes from the run's summary.
- **Run Caddy as root with only `CAP_NET_BIND_SERVICE`.** Common, but a
  root process in a container is one kernel bug away from root on the
  host; the sysctl gives the same port binding without it.
- **Publish Postgres on `127.0.0.1` for admin access.** Convenient, but an
  ssh tunnel to the container network or `docker compose exec postgres
  psql` does the same without a listening port (docs/operations.md).

## Consequences

- `docker compose up` alone does not migrate: always go through Ansible
  (`site.yml`, later `deploy.yml`) or run `migrate` by hand first.
- `docker compose config` prints secrets from the env files; use
  `--quiet` (CI does) or read `compose.yml` itself.
- Changing a Postgres password in the vault does not change it in an
  initialised database (docs/operations.md, "Rotating secrets").
- Phase 6 must keep `stack_api_colors` and `stack_active_color` in sync
  with the deploy state, or a `site.yml` run would switch colors back.
