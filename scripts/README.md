# scripts

Shell scripts, checked by shellcheck.

| Script | Runs on | What |
|---|---|---|
| `local-server.sh` | workstation | Builds, starts, stops and removes the local server container (ADR-0007) |
| `with-local-keys.sh` | toolbox | Puts the local server's ssh keys and vault password in place, then runs a command |
| `gen-local-vault.sh` | toolbox | Creates the local vault and its password once (ADR-0006) |
| `check-idempotence.sh` | toolbox | Runs a playbook, fails unless every host reports `changed=0` |
| `smoke-test.sh` | workstation, CI, server | HTTPS smoke test through the public URL: TLS, redirect, headers, version, register → monitor → check |
| `port-scan.sh` | toolbox, on the server's network | Only the expected ports answer (22, 80, 443) |

Later: `gen-inventory.sh` (Phase 5), `check-runbooks.sh` (Phase 4),
`backup.sh` (Phase 7).
