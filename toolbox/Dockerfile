# Toolbox: the pinned Linux environment in which every check of this
# repository runs, locally (native Windows, no WSL) and in CI alike
# (docs/adr/0002-toolbox-container.md). Later phases add Ansible, Terraform
# and the other linters here.
FROM python:3.14.10-slim-trixie

# git: pre-commit clones the hook repositories and lists the tracked files.
# hadolint DL3008 (pin apt versions) is deliberately not followed: Debian
# removes old package versions from its mirrors, so exact pins break builds;
# the base image tag is the pin.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --root-user-action=ignore -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# The repository is bind-mounted from the host, so its owner differs from
# the container user and git refuses to work in it ("dubious ownership").
# The container only ever sees this one repository.
RUN git config --system --add safe.directory '*'

# Hook environments live in a named volume (see the Makefile), so they are
# installed once, not on every run.
ENV PRE_COMMIT_HOME=/cache/pre-commit

WORKDIR /repo
