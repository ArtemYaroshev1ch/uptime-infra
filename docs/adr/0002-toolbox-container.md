# 0002. All tooling runs in a pinned toolbox container

- Status: accepted
- Date: 2026-11-06

## Context

The workstation is native Windows 11 without WSL and without Python. Ansible
does not support Windows as a control node, and the Python linters
(pre-commit, yamllint, ansible-lint) would each need a local Python setup.
CI runs on Linux. Checks that pass on one machine and fail on another waste
time, so the local run and the CI run should be the same command in the same
environment.

## Decision

`toolbox/Dockerfile` builds a Linux image (`python:<exact>-slim-trixie`) with
every tool this repository needs, pinned to exact versions. `make` targets
run the tools inside it with the repository bind-mounted at `/repo`:

- `make lint` — `pre-commit run --all-files` (yamllint, shellcheck,
  actionlint, hadolint, file hygiene). Hook versions are pinned in
  `.pre-commit-config.yaml`; their environments are cached in the named
  volume `uptime-infra-toolbox-cache`.
- `make shell` — an interactive shell for ad-hoc commands
  (`pre-commit autoupdate`, later `ansible-playbook`, `terraform`).
- CI calls the same `make` targets on `ubuntu-24.04`.

Later phases extend the image with Ansible, Terraform, tflint, promtool and
the other tools as they are needed. The image is built locally and never
published.

`gitleaks` runs from its official pinned image (`make secrets`), as in
`uptime-monitor`.

## Alternatives

- **WSL2 or a native Python install.** Works, but it is per-machine setup
  that CI does not share, and WSL is not used on this workstation.
- **Ansible inside the Vagrant VM (`ansible_local` provisioner).** Fine for
  the local VM, but cannot drive a remote server from the workstation and
  still leaves the linters without a home.
- **pre-commit as a git hook on the host.** Needs Python on the host; with
  the toolbox, `make lint` before a commit gives the same result.

## Consequences

- Docker Desktop must be running for any check.
- The first `make lint` downloads the hook environments (about a minute);
  later runs reuse the cache volume.
- Files that hooks fix (trailing whitespace, end of file) are written by
  root inside the container; on Windows bind mounts this is invisible, on a
  Linux workstation the fixed files may end up owned by root.
