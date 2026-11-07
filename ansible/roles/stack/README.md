# stack

The `uptime-monitor` stack as one Docker Compose project (`uptime`) in
`/opt/uptime`: PostgreSQL, the migrations, the API, the worker and Caddy.
Design and trade-offs: `docs/adr/0005-application-stack.md`.

```
/opt/uptime/
├── compose.yml          rendered from templates/compose.yml.j2
├── env/                 0700 root
│   ├── app.env          0600: DATABASE_URL, JWT_SECRET, TELEGRAM_BOT_TOKEN
│   └── postgres.env     0600: POSTGRES_PASSWORD (first start only)
└── caddy/
    ├── etc/Caddyfile    mounted read-only as a directory
    ├── data/            certificates, Caddy's local CA (owner 65532)
    └── config/          Caddy's autosaved config (owner 65532)
```

| Service | Image | Networks | Notes |
|---|---|---|---|
| `postgres` | `postgres:16.15-alpine3.24` | backend | volume `uptime_pgdata`, user 70, not published |
| `migrate` | app image | backend | profile `tools`; run by the role, never by `up` |
| `api-<color>` | app image | edge, backend | one per color in `stack_api_colors`; ops port 9090 not published |
| `worker` | app image | backend | ops port 9091 not published |
| `caddy` | `caddy:2.11.9-alpine` | edge | the only published ports: 80, 443/tcp, 443/udp |

Every container: pinned tag, `restart: unless-stopped` (except `migrate`),
healthcheck, `mem_limit`/`cpus`, json-file log rotation,
`cap_drop: [ALL]`, `no-new-privileges`, read-only root filesystem, no root.

## What a run does

1. Checks the variables (`app_version` is SemVer without `v`, the vault has
   `postgres_password` and `jwt_secret`).
2. Writes the files above. The env files are written with `no_log`.
3. Starts `postgres` and waits until it is healthy.
4. `docker compose run --rm migrate`: `changed` only if migrations were
   applied (the JSON log says `"applied":0` otherwise). Skipped in
   `--check` mode.
5. `docker compose up --wait` for the rest, removing orphans. Compose
   recreates only containers whose configuration changed, so a second run
   reports `changed=0`.
6. A changed Caddyfile triggers `caddy reload` (graceful).

## Variables

Required from the inventory: `app_version`, `domain`, and from the vault
`postgres_password` (16+ chars), `jwt_secret` (32+ chars),
`telegram_bot_token` (may be empty).

| Variable | Default | Meaning |
|---|---|---|
| `stack_dir` | `/opt/uptime` | Where the files live |
| `stack_project` | `uptime` | Compose project name |
| `stack_app_image` | `ghcr.io/artemyaroshev1ch/uptime-monitor` | Without the tag (`app_version`) |
| `stack_postgres_image`, `stack_caddy_image` | see `defaults/main.yml` | Exact tags |
| `stack_api_colors` | `{blue: "{{ app_version }}"}` | Color → version; a color without version is not rendered |
| `stack_active_color` | `blue` | The color Caddy proxies to |
| `stack_app_host` | `app.{{ domain }}` | Public host name |
| `stack_tls_internal` | `false` | `true`: Caddy's own CA (local server) instead of Let's Encrypt |
| `stack_acme_email` | `""` | Let's Encrypt account e-mail |
| `stack_limits` | see `defaults/main.yml` | Memory and CPU per service |
| `stack_wait_timeout` | `300` | Seconds `up --wait` waits for healthy |

## Checks

- `make test-compose`: renders the template for `local` and `prod` in the
  toolbox and runs `docker-compose config --quiet` (CI job `compose`).
- `make test-ansible`: Molecule runs the role inside its container (stack
  idempotence in CI).
- `make local-verify`: every service runs and is healthy; no container on
  the host publishes anything but 80/443.
- `make local-smoke`: `scripts/smoke-test.sh` through Caddy over HTTPS.
- `make local-scan`: `scripts/port-scan.sh` from the workstation.
