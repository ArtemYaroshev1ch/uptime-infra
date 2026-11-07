# Operations

How to run and look after the stack. Grows with every phase: deploy and
rollback (Phase 6), backups (Phase 7).

## Where things are

Everything of the application lives in `/opt/uptime` on the host (layout in
`ansible/roles/stack/README.md`). Docker data is in `/var/lib/docker`.

| Data | Where | Size (local server, Phase 2) | Lost on |
|---|---|---|---|
| PostgreSQL | named volume `uptime_pgdata` | < 100 MB, grows with checks (`CHECKS_RETENTION_DAYS`, 30) | volume deletion |
| Caddy certificates and local CA | `/opt/uptime/caddy/data` | < 1 MB | directory deletion (re-issued automatically) |
| Container logs | `/var/lib/docker/containers/*/` | ≤ 3 × 10 MB per container | rotation |

Phase 3 adds the Prometheus, Loki and Grafana volumes here.

## Everyday commands

The `deploy` user is not in the `docker` group (that would be root without
sudo's audit trail), so every docker command needs `sudo`.

```sh
make local-ssh                                 # or ssh deploy@<host>
cd /opt/uptime
sudo docker compose ps                         # state and health
sudo docker compose logs -f --tail 50 worker   # logs (JSON)
sudo docker compose exec postgres psql -U uptime uptime
```

Do not run `docker compose up` by hand after changing the image version:
migrations run only through Ansible (`docs/adr/0005-application-stack.md`).
Change `app_version` and run `site.yml` (Phase 6: `deploy.yml`).

## Access to internal services

Nothing but Caddy (80, 443) is published, by design. Reach the rest over
ssh:

```sh
# Postgres from the workstation: forward a local port to the container.
ssh -L 15432:<postgres container IP>:5432 deploy@<host>
# The IP: sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' uptime-postgres-1
```

## Secrets

Secrets live in Ansible Vault (`group_vars/all/vault.yml`): encrypted in
the repository for production (password outside it and in the
`VAULT_PASSWORD` GitHub secret), generated and gitignored for the local server
(`docs/adr/0006-local-secrets-and-tls.md`). On the host they end up only in
`/opt/uptime/env/*.env` (0600, root).

```sh
make shell
ansible-vault view   ansible/inventories/local/group_vars/all/vault.yml   # local
ansible-vault edit   ansible/inventories/prod/group_vars/all/vault.yml    # prod
```

### Rotating secrets

| Secret | Steps | Effect |
|---|---|---|
| `jwt_secret` | edit the vault, run `site.yml` | api and worker are recreated; every user must log in again |
| `postgres_password` | 1. `sudo docker compose exec postgres psql -U uptime -c "ALTER ROLE uptime PASSWORD '<new>'"` 2. edit the vault 3. run `site.yml` | the env files change, api and worker reconnect. The image reads `POSTGRES_PASSWORD` only on the first start, so step 1 is required |
| `telegram_bot_token` | revoke in @BotFather, edit the vault, run `site.yml` | api and worker are recreated |

A secret that leaked into a commit or a log: rotate it first, then clean
the history.

## Health checks

```sh
make local-verify   # host hardening + stack healthy + only 80/443 published
make local-smoke    # HTTPS end to end: register, monitor, the worker checks it
make local-scan     # port scan from another container on the server's network
```
