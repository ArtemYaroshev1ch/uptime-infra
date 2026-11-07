#!/usr/bin/env bash
# Scans a host from outside and checks that only the expected ports answer:
#
#   scripts/port-scan.sh 172.30.56.10        # make local-scan (from the toolbox)
#
# The point is Docker: a published container port gets Docker's own
# iptables rules and bypasses ufw, so "ufw is active" proves nothing about
# containers. Only a connection attempt from another machine does.
#
# A TCP connect per port with bash's /dev/tcp and a timeout: no nmap
# needed, works from Git for Windows' bash. A port counts as open when the
# connection is accepted; ufw drops the rest, so they time out.
set -euo pipefail

host="${1:?usage: port-scan.sh HOST}"
timeout_s="${SCAN_TIMEOUT:-2}"

# Must answer: ssh and Caddy.
expected_open=(22 80 443)
# Must not: postgres, the ops ports of api and worker, the api port behind
# Caddy, Caddy's admin API, the Docker API, and the ports of later phases
# (Grafana, Prometheus, Alertmanager, Loki, exporters).
expected_closed=(5432 8080 9090 9091 2019 2375 2376 3000 9093 3100 9100 8081 9187 9115)

is_open() {
  timeout "$timeout_s" bash -c "exec 3<>/dev/tcp/$host/$1" 2>/dev/null
}

failures=0
echo "Port scan of $host"
for port in "${expected_open[@]}"; do
  if is_open "$port"; then
    printf 'ok    %-5s open\n' "$port"
  else
    printf 'FAIL  %-5s closed, want open\n' "$port"
    failures=$((failures + 1))
  fi
done
for port in "${expected_closed[@]}"; do
  if is_open "$port"; then
    printf 'FAIL  %-5s OPEN, want closed\n' "$port"
    failures=$((failures + 1))
  else
    printf 'ok    %-5s closed\n' "$port"
  fi
done

if ((failures > 0)); then
  echo "port scan FAILED: $failures port(s)"
  exit 1
fi
echo "port scan passed: only ${expected_open[*]} answer"
