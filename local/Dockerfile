# A fresh Ubuntu 26.04 "server" as a privileged container with systemd as
# PID 1 (docs/adr/0007-local-environment-in-a-container.md). Used by:
#   - the local environment (scripts/local-server.sh, `make local-up`);
#   - Molecule in CI (ansible/molecule/default/molecule.yml).
# Ansible configures it like a cloud host: root logs in with a key once
# (bootstrap.yml), everything else runs as `deploy` over ssh.
# The dated tag pins the base image.
FROM ubuntu:resolute-20261024.1

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive

# What a cloud image ships and the roles expect to find: systemd, python3
# for Ansible, sudo and the OpenSSH server. Masked units cannot work in a
# container (no consoles, no logind seats, no kernel module loading: the
# kernel is the Docker host's) and would only leave systemd "degraded".
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd systemd-sysv python3 python3-apt sudo openssh-server \
        ca-certificates iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl mask systemd-logind.service getty.target console-getty.service \
        systemd-modules-load.service \
    && systemctl enable ssh.service

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
