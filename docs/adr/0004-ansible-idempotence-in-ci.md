# 0004. Ansible idempotence is tested with Molecule in a systemd container

- Status: accepted
- Date: 2026-11-06

## Context

Every Ansible change must keep `site.yml` idempotent: a second run on a
configured host reports `changed=0` (PROMPT.md §2, §9). A non-idempotent
task either hides real drift (it is "changed" every time, so nobody looks)
or restarts services on every run. The check has to run in CI on every PR,
where the Vagrant VM of the local environment does not exist.

The roles manage systemd services (ssh, fail2ban, unattended-upgrades,
docker), ufw (iptables) and Docker Engine itself, so a plain container is
not a good enough target.

## Decision

- **Molecule** (`ansible/molecule/default`, docker driver) runs `site.yml`
  in a privileged Ubuntu 26.04 container with systemd as PID 1:
  `create → converge → idempotence → verify → destroy`. The idempotence
  step runs the playbook again and fails on any `changed` task; `verify`
  runs `ansible/playbooks/verify.yml`.
- `make test` runs it inside the toolbox with the host's Docker socket
  mounted; CI runs the same target (job `ansible`).
- Differences from a real host, set in `molecule.yml`:
  - kernel parameters are written to `/etc/sysctl.d` but not applied
    (`common_sysctl_apply: false`): a privileged container shares the kernel
    of the machine running it;
  - the login checks from the control node are skipped
    (`verify_from_controller: false`): Molecule connects with `docker exec`,
    not ssh.
- The **local VM** is the full check: `make local-idempotence` runs
  `site.yml` against it and fails unless every host reports `changed=0`,
  and `make local-verify` also tries the refused logins over real ssh.

## Alternatives

- **Vagrant in CI.** The real thing, but GitHub-hosted runners would need
  nested virtualization and several minutes to boot a box; the VM stays
  the local check.
- **Run the playbook against the GitHub runner itself.** A real VM with
  systemd, but it is Ubuntu 24.04 with Docker preinstalled from other
  packages, and hardening ssh/ufw on a shared runner image is fragile.
- **Only `ansible-lint` and `--syntax-check` in CI.** Allowed by the
  specification, but it catches no idempotence bug.

## Consequences

- CI needs Docker with privileged containers (GitHub-hosted runners have
  it) and takes a few minutes longer.
- The Molecule target trusts systemd-in-Docker; a role that behaves
  differently in a container than on a VM (for example a new kernel
  setting) needs a variable like `common_sysctl_apply` and a note here.
- The test does not prove that the operator keeps ssh access; that part is
  checked on the VM by `make local-verify`.
