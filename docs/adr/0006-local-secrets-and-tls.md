# 0006. Local environment: generated vault, sslip.io and Caddy's own CA

- Status: accepted
- Date: 2026-11-07

## Context

The stack needs secrets (Postgres password, JWT secret, later Grafana and
S3) from Ansible Vault and a public HTTPS name (PROMPT.md §9, §10). The
local VM (ADR-0003) sits on a host-only network: no domain, no way for
Let's Encrypt to reach it, and nothing in it is worth protecting beyond
the workstation.

## Decision

- **Local secrets are generated, not committed.** On first use
  `scripts/gen-local-vault.sh` (called by `scripts/with-local-keys.sh`)
  creates:
  - `local/.vault-pass`: a random vault password;
  - `ansible/inventories/local/group_vars/all/vault.yml`: random values,
    encrypted with that password.

  Both are gitignored. Existing files are never overwritten: Postgres was
  initialised with the password in them. The toolbox gets a 0600 copy of
  the password file through `ANSIBLE_VAULT_PASSWORD_FILE` (on a Windows
  bind mount the file looks executable, and Ansible would try to run it).
- **Production keeps the specification's model:** an encrypted
  `inventories/prod/group_vars/all/vault.yml` (committed) with the
  password outside the repository and in the `VAULT_PASSWORD` GitHub
  secret. Only `vault.yml.example` exists now; CI renders the stack with
  its placeholders.
- **Host name via sslip.io:** `domain: 192.168.56.10.sslip.io`, so the
  application is `https://app.192.168.56.10.sslip.io`. Public DNS resolves
  it to the VM; no hosts-file edits.
- **TLS from Caddy's own CA (`tls internal`).** `make local-ca` fetches the
  root certificate to `local/caddy-root.crt` (gitignored); the smoke test
  trusts exactly that file instead of using `--insecure`, and the operator
  may import it into the browser (local/README.md).

## Alternatives

- **A committed local vault with a well-known password.** Reproducible,
  but trains the habit of committing secrets and adds noise to gitleaks.
- **Plain variables for local secrets.** Simplest, but then the local
  environment no longer exercises the vault path production uses.
- **A self-signed certificate made by Ansible, or mkcert.** More moving
  parts; Caddy already runs a CA and renews its certificates.
- **`curl --insecure` in the smoke test.** Would not notice a wrong
  certificate, a wrong host name or a broken chain.

## Consequences

- A fresh clone gets new local secrets automatically; recreating the VM
  with an old vault works, deleting the vault of a running VM breaks the
  database login (delete the `uptime_pgdata` volume too, or keep the file).
- The smoke test depends on public DNS for sslip.io. Some routers block
  DNS answers with private addresses ("DNS rebinding protection"); then
  add `192.168.56.10 app.192.168.56.10.sslip.io` to the hosts file.
- On Windows, curl (Schannel) cannot check revocation for a private CA;
  the smoke test passes `--ssl-no-revoke` together with `--cacert`.
