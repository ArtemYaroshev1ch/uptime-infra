# docker

Docker Engine and the Compose v2 plugin from Docker's official apt
repository.

- Removes Ubuntu's own builds (`docker.io`, `containerd`, ...) that conflict
  with Docker's packages.
- Downloads Docker's signing key and checks its SHA-256: a changed key
  fails the run. The repository is a deb822 source with `Signed-By`, so the
  key is trusted for this repository only.
- Installs **exact** package versions (`docker_version` and friends). An
  engine upgrade restarts containers, so it is a reviewed change of these
  variables, never a side effect of `apt upgrade`; `unattended-upgrades`
  skips these packages too (role `common`).
- `/etc/docker/daemon.json`:
  - `json-file` logs rotated at `10m` x `3` per container, so container logs
    cannot fill the disk;
  - `live-restore: true`: containers keep running while `dockerd` restarts.

The `deploy` user is **not** added to the `docker` group: membership is
equivalent to root without a password prompt or an audit trail. Ansible
uses `become`; for ad-hoc work use `sudo docker ...`.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `docker_version` | `5:29.9.3-1~ubuntu.26.04~resolute` | `docker-ce` and `docker-ce-cli` |
| `docker_containerd_version` | `2.4.2-3~...` | `containerd.io` |
| `docker_compose_version` | `5.7.0-1~...` | `docker-compose-plugin` |
| `docker_buildx_version` | `0.38.1-1~...` | `docker-buildx-plugin` |
| `docker_gpg_key_checksum` | `sha256:1500c1f5...` | Expected signing key |
| `docker_log_max_size`, `docker_log_max_file` | `10m`, `3` | Log rotation |
| `docker_live_restore` | `true` | Keep containers running across daemon restarts |

## Upgrading Docker

```sh
make local-ssh   # then, on the host:
apt-cache madison docker-ce docker-compose-plugin containerd.io docker-buildx-plugin
```

Change the version variables in one PR; the handler restarts `dockerd`
(containers survive thanks to `live-restore`).
