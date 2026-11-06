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

GITLEAKS_IMAGE := ghcr.io/gitleaks/gitleaks:v8.30.1

##@ General

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## " } \
		/^##@/ { printf "\n%s\n", substr($$0, 5) } \
		/^[a-zA-Z0-9_-]+:.*## / { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Toolbox

toolbox: ## Build the toolbox image (pinned linters, later Ansible and Terraform)
	docker build --quiet --tag $(TOOLBOX_IMAGE) toolbox

shell: toolbox ## Open a shell in the toolbox with the repository mounted
	$(TOOLBOX) bash

##@ Checks

lint: toolbox ## Run every pre-commit hook on all files (yamllint, shellcheck, actionlint, hadolint, ...)
	$(TOOLBOX) pre-commit run --all-files --show-diff-on-failure --color=always

test: ## Run the tests (none yet: promtool rule tests arrive in Phase 4, Go tests in Phase 7)
	@echo "No tests yet: Phase 4 adds promtool rule tests, Phase 7 the restore-verifier tests."

# The whole history, not just the working tree: a secret removed in a later
# commit is still in the repository. Findings are redacted in the output.
secrets: ## Look for secrets in the git history (gitleaks)
	docker run --rm -v "$(CURDIR):/repo" $(GITLEAKS_IMAGE) \
		git /repo --no-banner --redact

.PHONY: help toolbox shell lint test secrets
