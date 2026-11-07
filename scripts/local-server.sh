#!/usr/bin/env bash
# The local "server": a privileged Ubuntu container with systemd, sshd and
# its own Docker engine, on a Docker network of its own
# (docs/adr/0007-local-environment-in-a-container.md). Runs on the
# workstation (Git Bash on Windows) and talks to Docker Desktop.
#
#   scripts/local-server.sh up        build, create or start; authorize root's bootstrap key
#   scripts/local-server.sh halt      stop (keeps everything)
#   scripts/local-server.sh destroy   remove the container and its volumes
#   scripts/local-server.sh status
#
# The address 172.30.56.10 is fixed: the inventory, fail2ban's ignore list
# and the port scan use it. Caddy's 80/443 are published on 127.0.0.1 only.
set -euo pipefail

# Git Bash would rewrite /sys/fs/cgroup and friends into Windows paths
# before they reach docker.exe.
export MSYS_NO_PATHCONV=1

name=uptime-local
image=uptime-local:resolute
network=uptime-local
subnet=172.30.56.0/24
ip=172.30.56.10
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
bootstrap_pub="$repo_root/local/.ssh/bootstrap.pub"

exists() { docker container inspect "$name" >/dev/null 2>&1; }
running() { [[ "$(docker container inspect -f '{{.State.Running}}' "$name" 2>/dev/null)" == true ]]; }

up() {
  # Relative path: with path conversion off, docker.exe on Windows would
  # not understand Git Bash's /d/projects/...
  (cd "$repo_root" && docker build --quiet --tag "$image" local >/dev/null)
  docker network inspect "$network" >/dev/null 2>&1 ||
    docker network create --subnet "$subnet" "$network" >/dev/null

  if ! exists; then
    # privileged + host cgroup namespace + writable cgroupfs: systemd as
    # PID 1 and dockerd inside. /var/lib/docker and containerd live in
    # named volumes: overlayfs cannot sit on overlayfs, and pulled images
    # and the database survive `halt`.
    docker run --detach --name "$name" --hostname "$name" \
      --network "$network" --ip "$ip" \
      --privileged --cgroupns host \
      --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
      --volume "$name-docker:/var/lib/docker" \
      --volume "$name-containerd:/var/lib/containerd" \
      --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
      --publish 127.0.0.1:80:80 \
      --publish 127.0.0.1:443:443 \
      --publish 127.0.0.1:443:443/udp \
      "$image" >/dev/null
    echo "Created $name ($ip)"
  elif ! running; then
    docker start "$name" >/dev/null
    echo "Started $name"
  else
    echo "$name is running"
  fi

  # Wait for systemd to bring sshd up.
  for _ in $(seq 1 30); do
    docker exec "$name" systemctl is-active --quiet ssh 2>/dev/null && break
    sleep 1
  done

  # A cloud image comes with root's key installed; so does this one. Only
  # until the deploy user exists: bootstrap.yml uses it once, then
  # ssh_hardening forbids root logins.
  if ! docker exec "$name" id deploy >/dev/null 2>&1; then
    docker exec -i "$name" sh -c \
      'install -d -m 0700 /root/.ssh && cat >/root/.ssh/authorized_keys && chmod 0600 /root/.ssh/authorized_keys' \
      <"$bootstrap_pub"
  fi
}

case "${1:-}" in
  up) up ;;
  halt)
    if exists; then
      docker stop "$name" >/dev/null
      echo "Stopped $name"
    fi
    ;;
  destroy)
    docker rm --force "$name" >/dev/null 2>&1 || true
    docker volume rm "$name-docker" "$name-containerd" >/dev/null 2>&1 || true
    docker network rm "$network" >/dev/null 2>&1 || true
    echo "Removed $name, its volumes and network"
    ;;
  status)
    if running; then echo "$name: running ($ip)"; elif exists; then echo "$name: stopped"; else echo "$name: absent"; fi
    ;;
  *)
    echo "usage: $0 up|halt|destroy|status" >&2
    exit 2
    ;;
esac
