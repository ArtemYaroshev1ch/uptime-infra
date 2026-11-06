#!/usr/bin/env bash
# Runs a playbook and fails unless every host reports changed=0, failed=0
# and unreachable=0: the run after a converged run must change nothing.
#
#   scripts/check-idempotence.sh ansible/playbooks/site.yml [ansible args]
set -euo pipefail

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# The playbook output stays visible; the recap is checked afterwards.
ANSIBLE_FORCE_COLOR=1 ansible-playbook "$@" | tee "$log"

recap="$(sed -n '/PLAY RECAP/,$p' "$log" | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'ok=[0-9]+' || true)"
if [[ -z "$recap" ]]; then
  echo "check-idempotence: no PLAY RECAP in the output" >&2
  exit 1
fi

if grep -Ev 'changed=0 .*unreachable=0 +failed=0' <<<"$recap" >&2; then
  echo "check-idempotence: FAILED, the hosts above changed something on the second run" >&2
  exit 1
fi
echo "check-idempotence: OK, changed=0 on every host"
