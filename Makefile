# Operator and developer tasks for uptime-infra. Run `make help` for the list.
#
# Every check runs inside the toolbox container (toolbox/Dockerfile), so the
# host needs only Docker, make and git; CI calls the same targets
# (docs/adr/0002-toolbox-container.md).
#
# Portability: recipes are POSIX sh. On Linux/macOS that is the default. On
# native Windows, GNU Make uses sh.exe when it finds it in PATH (Git for
# Windows puts it in "C:\Program Files\Git\bin"); otherwise it silently falls
# back to cmd.exe, so we check for that up front.
ifeq ($(shell echo $$0),$$0)
$(error This Makefile needs a POSIX shell, but make is using cmd.exe. Add "C:\Program Files\Git\bin" to PATH or run make from Git Bash)
endif

ifeq ($(OS),Windows_NT)
# Make starts simple recipe lines (no shell metacharacters) directly, without
# sh, so coreutils (echo, awk) must be in PATH. Git for Windows keeps them in
# usr\bin, which is not in PATH outside Git Bash. The redirect forces this
# command through sh, which knows where /usr/bin is.
POSIX_BIN := $(shell cygpath -w /usr/bin 2>/dev/null)
export PATH := $(POSIX_BIN);$(PATH)
# Git Bash rewrites arguments that look like Unix paths (/repo becomes
# C:/Program Files/Git/repo) before they reach docker.exe.
export MSYS_NO_PATHCONV := 1
endif

.DEFAULT_GOAL := help

# The toolbox image is built locally from toolbox/; it is never pushed.
TOOLBOX_IMAGE := uptime-infra-toolbox:local
# Hook environments of pre-commit survive between runs in this volume.
TOOLBOX_CACHE := uptime-infra-toolbox-cache

# -t only when make itself runs in a terminal: CI has none, and docker
# refuses -t without one.
TTY := $(shell [ -t 0 ] && echo -t)
TOOLBOX := docker run --rm -i $(TTY) \
	-v "$(CURDIR):/repo" \
	-v $(TOOLBOX_CACHE):/cache \
	$(TOOLBOX_IMAGE)

# Molecule starts its test container next to the toolbox, on the host's
# Docker engine.
TOOLBOX_DOCKER := docker run --rm -i $(TTY) \
	-v "$(CURDIR):/repo" \
	-v $(TOOLBOX_CACHE):/cache \
	-v /var/run/docker.sock:/var/run/docker.sock \
	$(TOOLBOX_IMAGE)

# Ansible against the local VM, with its ssh keys in place.
LOCAL_ANSIBLE := $(TOOLBOX) scripts/with-local-keys.sh
# Vagrant runs on the host (it drives VirtualBox) from local/.
export VAGRANT_CWD := $(CURDIR)/local

GITLEAKS_IMAGE := ghcr.io/gitleaks/gitleaks:v8.30.1

##@ General

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## " } \
		/^##@/ { printf "\n%s\n", substr($$0, 5) } \
		/^[a-zA-Z0-9_-]+:.*## / { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Toolbox

toolbox: ## Build the toolbox image (pinned linters, later Ansible and Terraform)
	docker build --quiet --tag $(TOOLBOX_IMAGE) --file toolbox/Dockerfile .

shell: toolbox ## Open a shell in the toolbox with the repository mounted
	$(TOOLBOX) bash

##@ Checks

lint: toolbox ## Run every pre-commit hook on all files (yamllint, shellcheck, actionlint, hadolint, ...)
	$(TOOLBOX) pre-commit run --all-files --show-diff-on-failure --color=always

test: test-ansible ## Run every test

test-ansible: toolbox ## Molecule: site.yml twice in a systemd container, the second run must report changed=0
	$(TOOLBOX_DOCKER) sh -c 'cd ansible && molecule test'

# The whole history, not just the working tree: a secret removed in a later
# commit is still in the repository. Findings are redacted in the output.
secrets: ## Look for secrets in the git history (gitleaks)
	docker run --rm -v "$(CURDIR):/repo" $(GITLEAKS_IMAGE) \
		git /repo --no-banner --redact

##@ Local environment (Vagrant VM, docs/adr/0003-local-only-environment.md)

local-up: ## Create/start the VM and configure it (bootstrap + site)
	vagrant up
	$(MAKE) local-bootstrap local-site

local-bootstrap: toolbox ## Create the deploy user (logs in as vagrant)
	$(LOCAL_ANSIBLE) ansible-playbook ansible/playbooks/bootstrap.yml

local-site: toolbox ## Apply site.yml to the VM
	$(LOCAL_ANSIBLE) ansible-playbook ansible/playbooks/site.yml

local-check: toolbox ## Dry run of site.yml against the VM (--check --diff)
	$(LOCAL_ANSIBLE) ansible-playbook ansible/playbooks/site.yml --check --diff

local-idempotence: toolbox ## Run site.yml again and fail unless it reports changed=0
	$(LOCAL_ANSIBLE) scripts/check-idempotence.sh ansible/playbooks/site.yml

local-verify: toolbox ## Check the VM: no password or root login, ufw active, Docker works
	$(LOCAL_ANSIBLE) ansible-playbook ansible/playbooks/verify.yml

local-ssh: ## Open a shell on the VM as the vagrant user
	vagrant ssh

local-halt: ## Stop the VM (keeps its disk)
	vagrant halt

# Never run by the assistant without an explicit request (CLAUDE.md).
local-destroy: ## Delete the VM and its disk
	vagrant destroy

.PHONY: help toolbox shell lint test test-ansible secrets \
	local-up local-bootstrap local-site local-check local-idempotence \
	local-verify local-ssh local-halt local-destroy
