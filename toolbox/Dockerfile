# Toolbox: the pinned Linux environment in which every check of this
# repository runs, locally (native Windows, no WSL) and in CI alike
# (docs/adr/0002-toolbox-container.md). Later phases add Terraform and the
# other linters here.
#
# Build context is the repository root (see .dockerignore): the image also
# needs ansible/requirements.yml.
FROM python:3.14.10-slim-trixie

# git: pre-commit clones the hook repositories and lists the tracked files.
# openssh-client: Ansible connects to hosts over ssh; ssh-keygen creates the
# local deploy key.
# rsync: Molecule copies scenario files with ansible.posix.synchronize.
# hadolint DL3008 (pin apt versions) is deliberately not followed: Debian
# removes old package versions from its mirrors, so exact pins break builds;
# the base image tag is the pin.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends git openssh-client rsync \
    && rm -rf /var/lib/apt/lists/*

# Compose, standalone binary: `make test-compose` validates the rendered
# Compose file with `docker-compose config`, which needs no daemon. Same
# version as the docker-compose-plugin on the hosts (role docker); the
# checksums come from the release's checksums.txt.
ARG COMPOSE_VERSION=5.7.0
ARG COMPOSE_SHA256_X86_64=7758048ad38e580f22559603312874fec8bb638d021a9e64182385fc17cc12a2
ARG COMPOSE_SHA256_AARCH64=15861535d14e26555736b49376c95e14bfd94285366c8446bfac7156a972e76f
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN arch="$(uname -m)" \
    && case "$arch" in \
         x86_64) sum="$COMPOSE_SHA256_X86_64" ;; \
         aarch64) sum="$COMPOSE_SHA256_AARCH64" ;; \
         *) echo "unsupported architecture: $arch" >&2; exit 1 ;; \
       esac \
    && python3 -c "import urllib.request, sys; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])" \
         "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-${arch}" \
         /usr/local/bin/docker-compose \
    && echo "${sum}  /usr/local/bin/docker-compose" | sha256sum -c - \
    && chmod 0755 /usr/local/bin/docker-compose

COPY toolbox/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --root-user-action=ignore -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Ansible collections, pinned in ansible/requirements.yml, are baked into
# the image: playbooks, ansible-lint and Molecule all see the same versions.
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections
COPY ansible/requirements.yml /tmp/ansible-requirements.yml
RUN ansible-galaxy collection install --no-cache \
        -r /tmp/ansible-requirements.yml -p "$ANSIBLE_COLLECTIONS_PATH" \
    && rm /tmp/ansible-requirements.yml

# The repository is bind-mounted from the host, so its owner differs from
# the container user and git refuses to work in it ("dubious ownership").
# The container only ever sees this one repository.
RUN git config --system --add safe.directory '*'

# Hook environments live in a named volume (see the Makefile), so they are
# installed once, not on every run.
ENV PRE_COMMIT_HOME=/cache/pre-commit

# A Windows bind mount shows every directory as world-writable, and Ansible
# ignores an ansible.cfg in the current directory in that case. A path given
# explicitly is always read.
ENV ANSIBLE_CONFIG=/repo/ansible/ansible.cfg

WORKDIR /repo
