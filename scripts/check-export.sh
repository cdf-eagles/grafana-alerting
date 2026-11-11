#!/bin/sh
# Invariants of the Grafana export that a linter cannot express. They repeat
# what the writer (grafana-alert-export, soundwave.sleem.net's
# container_grafana_alert_export role) refuses to push, so a hand edit the
# next export would refuse fails here too.
#
#   sh scripts/check-export.sh
#
# 1. alerting/ holds exactly the four exported files, each non-empty.
# 2. Each starts with Grafana's file-provisioning header, apiVersion: 1.
# 3. alert-rules.yaml holds at least one rule.
# 4. No tracked file holds an ntfy access token (tk_ and 29 characters).
#
# YAML syntax is yamllint's job. Needs git.
set -eu

cd "$(git rev-parse --show-toplevel)"

failed=0
fail() {
  echo "FAIL  $1" >&2
  failed=$((failed + 1))
}

# 1. The file set.
expected="alerting/alert-rules.yaml
alerting/contact-points.yaml
alerting/mute-timings.yaml
alerting/notification-policies.yaml"
found=$(find alerting -type f | LC_ALL=C sort)
if [ "$found" != "$expected" ]; then
  fail "alerting/ holds:
$found
expected:
$expected"
fi

for f in $expected; do
  if [ ! -s "$f" ]; then
    fail "$f is missing or empty"
    continue
  fi
  # 2. The provisioning header.
  if [ "$(head -n 1 "$f")" != "apiVersion: 1" ]; then
    fail "$f does not start with 'apiVersion: 1'"
  fi
done

# 3. At least one rule, counted as the writer counts them.
rules=0
if [ -s alerting/alert-rules.yaml ]; then
  rules=$(grep -cE '^[[:space:]]+- uid:' alerting/alert-rules.yaml || true)
fi
if [ "$rules" -lt 1 ]; then
  fail "alerting/alert-rules.yaml holds no rule"
fi

# 4. ntfy tokens, over every tracked file. The list must not be empty, or the
# scan would pass having read nothing.
tracked=$(git ls-files | wc -l | tr -d ' ')
if [ "$tracked" -eq 0 ]; then
  fail "git ls-files lists no file to scan"
fi
if git ls-files -z | xargs -0 grep -lE 'tk_[a-z0-9]{29}' >&2; then
  fail "an ntfy token appears in the files above"
fi

if [ "$failed" -gt 0 ]; then
  echo "$failed check(s) failed" >&2
  exit 1
fi
echo "PASS  ${rules} rule(s); four export files; ${tracked} tracked files hold no ntfy token"
