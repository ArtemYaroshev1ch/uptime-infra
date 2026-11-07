#!/bin/sh
# Smoke test of a deployed stack through its public HTTPS endpoint, as a
# user sees it: TLS and the redirect, the probes and the version, then a
# user, a monitor and a check the worker actually ran. Leaves no monitor
# behind (the throwaway user stays: there is no delete-user API).
#
#   BASE_URL=https://app.example.com sh scripts/smoke-test.sh
#   make local-smoke        # the local server, trusting Caddy's local CA
#
# Environment:
#   BASE_URL          public URL of the application (required)
#   EXPECTED_VERSION  fail unless /version reports it (deploys set it)
#   SMOKE_CACERT      CA file to trust (Caddy's local CA); default: system
#   SMOKE_TARGET      site the test monitor checks (default https://example.com)
#   SMOKE_TIMEOUT     seconds to wait for readiness and the first check (90)
#
# POSIX sh and curl only (no bash, no jq): runs from Git for Windows' sh, a
# CI runner and the server alike. Exit code 0 = passed.

set -eu

: "${BASE_URL:?set BASE_URL, e.g. https://app.example.com}"
BASE_URL=${BASE_URL%/}
EXPECTED_VERSION=${EXPECTED_VERSION:-}
TARGET=${SMOKE_TARGET:-https://example.com}
TIMEOUT=${SMOKE_TIMEOUT:-90}

# A private CA (Caddy's tls internal) has no CRL or OCSP responder. Windows'
# curl (Schannel) fails closed on an unknown revocation status, so it is
# skipped for that CA only; the chain and the host name are still checked.
# Other TLS backends ignore --ssl-no-revoke.
if [ -n "${SMOKE_CACERT:-}" ]; then
	set -- --cacert "$SMOKE_CACERT" --ssl-no-revoke
else
	set --
fi

# Native Windows curl (Git for Windows' sh runs it) has no /dev/null.
case $(uname -s) in
MINGW* | MSYS* | CYGWIN*) null=NUL ;;
*) null=/dev/null ;;
esac

failures=0
pass() { printf 'ok    %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; failures=$((failures + 1)); }
die() { printf 'FAIL  %s\n' "$1"; exit 1; }

# check OK_MESSAGE FAIL_MESSAGE COMMAND...: a failed check is counted and
# the test goes on. require: the same, but the test cannot go on without it.
check() {
	ok=$1 bad=$2
	shift 2
	if "$@"; then pass "$ok"; else fail "$bad"; fi
}
require() {
	ok=$1 bad=$2
	shift 2
	if "$@"; then pass "$ok"; else die "$bad"; fi
}

# The CA option ("$@") goes to every request; certificate errors are real
# failures, never skipped with --insecure.
req() { curl -s --max-time 10 "$@"; }
status() { req "$@" -o "$null" -w '%{http_code}' || true; }

# json_field NAME: the first string value of "NAME":"..." on stdin.
json_field() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p" | head -n 1; }

# wait_for DESCRIPTION COMMAND...: retries every 2 s until TIMEOUT.
wait_for() {
	what=$1
	shift
	waited=0
	until "$@"; do
		if [ "$waited" -ge "$TIMEOUT" ]; then
			die "$what (gave up after ${TIMEOUT}s)"
		fi
		sleep 2
		waited=$((waited + 2))
	done
	pass "$what"
}

echo "Smoke test of $BASE_URL"

# --- edge: TLS, redirect, headers ----------------------------------------------
is_ready() { [ "$(status "$@" "$BASE_URL/readyz")" = 200 ]; }
wait_for "HTTPS with a trusted certificate, /readyz is 200" is_ready "$@"

http_url="http://${BASE_URL#https://}/healthz"
code=$(curl -s --max-time 10 -o "$null" -w '%{http_code} %{redirect_url}' "$http_url" || true)
case $code in
30[18]\ https://*) pass "plain HTTP redirects to HTTPS" ;;
*) fail "plain HTTP answered '$code', want a redirect to https://" ;;
esac

headers=$(req "$@" -D - -o "$null" "$BASE_URL/healthz" | tr -d '\r')
has_header() { printf '%s\n' "$headers" | grep -qi "$1"; }
lacks_header() { ! has_header "$1"; }
check "HSTS header" "no Strict-Transport-Security header" \
	has_header '^strict-transport-security: max-age='
check "X-Content-Type-Options header" "no X-Content-Type-Options header" \
	has_header '^x-content-type-options: nosniff'
check "no Server header" "the Server header is exposed" lacks_header '^server:'

# --- application ---------------------------------------------------------------
check "/healthz is 200" "/healthz is not 200" [ "$(status "$@" "$BASE_URL/healthz")" = 200 ]

version=$(req "$@" "$BASE_URL/version")
case $version in
*'"version":'*'"commit":'*'"built_at":'*) pass "/version: $version" ;;
*) fail "/version: unexpected answer: $version" ;;
esac
if [ -n "$EXPECTED_VERSION" ]; then
	got=$(printf '%s' "$version" | json_field version)
	check "version is $EXPECTED_VERSION" "version is '$got', want $EXPECTED_VERSION" \
		[ "$got" = "$EXPECTED_VERSION" ]
fi

# The ops port (9090) is not published; the public one never serves metrics.
code=$(status "$@" "$BASE_URL/metrics")
check "no /metrics on the public endpoint" "public /metrics answered $code, want 404" [ "$code" = 404 ]

# --- a user, a monitor and a check ---------------------------------------------
email="smoke-$(date +%s)-$$@example.com"
password="smoke-password-1"
creds="{\"email\":\"$email\",\"password\":\"$password\"}"
json='Content-Type: application/json'

code=$(status "$@" -X POST -H "$json" -d "$creds" "$BASE_URL/api/v1/auth/register")
require "register $email" "register answered $code, want 201" [ "$code" = 201 ]

token=$(req "$@" -X POST -H "$json" -d "$creds" "$BASE_URL/api/v1/auth/login" | json_field access_token)
require "login returns a token" "login returned no access_token" [ -n "$token" ]
auth="Authorization: Bearer $token"

monitor=$(req "$@" -X POST -H "$json" -H "$auth" \
	-d "{\"name\":\"smoke\",\"url\":\"$TARGET\",\"interval_seconds\":30}" \
	"$BASE_URL/api/v1/monitors" | json_field id)
require "create monitor $monitor for $TARGET" "monitor was not created" [ -n "$monitor" ]

# From here on, remove the monitor however the script ends. The CA option
# is saved now: "$@" inside a trap is the trap's own (empty) list.
cacert_opts=${SMOKE_CACERT:+--cacert $SMOKE_CACERT --ssl-no-revoke}
# shellcheck disable=SC2086 # cacert_opts is split into options on purpose
trap 'curl -s -o "$null" --max-time 10 $cacert_opts -X DELETE -H "$auth" "$BASE_URL/api/v1/monitors/$monitor" || true' EXIT

checked() {
	req "$@" -H "$auth" "$BASE_URL/api/v1/monitors/$monitor/checks?limit=1" | grep -q '"checked_at"'
}
wait_for "the worker checked the monitor" checked "$@"

last=$(req "$@" -H "$auth" "$BASE_URL/api/v1/monitors/$monitor/checks?limit=1")
case $last in
*'"success":true'*) pass "the check succeeded" ;;
*) fail "the check failed (does the host reach $TARGET?): $last" ;;
esac

echo
if [ "$failures" -gt 0 ]; then
	echo "smoke test FAILED: $failures check(s)"
	exit 1
fi
echo "smoke test passed"
