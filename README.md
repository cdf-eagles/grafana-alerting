# grafana-alerting

History of the homelab Grafana's alerting configuration, written by
automation. **This repository is not the source of truth.** Rules, contact
points, notification policies and mute timings are edited in the Grafana UI
and live in Grafana's database (`grafana` on mariadb01); this repository
records what they looked like, so a change can be seen, dated and reversed by
hand.

## What writes here

`grafana-alert-push.timer` on podman01, hourly, deployed by the
`container_grafana_alert_export` role in `soundwave.sleem.net`:

1. `grafana-alert-export` (curl) reads Grafana's provisioning export API and
   checks it: every request must succeed, at least one rule must exist, and
   no ntfy token (`tk_…`) may appear anywhere.
2. `grafana-alert-push` (git) clones this repository, replaces `alerting/`
   with the export, and commits and pushes **only if something changed**.

A failure in either step sends a push to ntfy topic `grafana`. Commits are
authored by `grafana-alert-export`; nobody else should push to `main`.

## Layout

| File | Grafana export |
| --- | --- |
| `alerting/alert-rules.yaml` | `/api/v1/provisioning/alert-rules/export` |
| `alerting/contact-points.yaml` | `/api/v1/provisioning/contact-points/export` (`decrypt=false`: secrets read `[REDACTED]`) |
| `alerting/notification-policies.yaml` | `/api/v1/provisioning/policies/export` |
| `alerting/mute-timings.yaml` | `/api/v1/provisioning/mute-timings/export` |

The files are in Grafana's file-provisioning format.

## Checks

CI (`.github/workflows/ci.yaml`) runs on every pull request to `main`, every
push to `main`, and weekly. It runs, once each:

- gitleaks over the full history;
- `scripts/check-export.sh`, the invariants the writer itself enforces: the
  four export files and no others, each starting `apiVersion: 1`, at least one
  rule, and no ntfy token anywhere;
- shellcheck on `scripts/`, `yamllint --strict` (`.yamllint.yaml` checks
  mistakes, not style, so Grafana's own formatting passes);
- the pre-commit hooks: workflow and Dependabot schemas, actionlint, and two
  private-key and secret scanners.

`CI` is a required status check on `main`. The writer's deploy key bypasses
the ruleset, so an export is pushed even if CI would fail it, and the push run
reports the failure afterwards; a pull request cannot merge on a red run.

To run the checks locally:

```sh
python3 -m venv .venv
.venv/bin/pip install -r ci/requirements.txt
PATH="$PWD/.venv/bin:$PATH"
sh scripts/check-export.sh
shellcheck -s sh scripts/*.sh
yamllint --strict .
pre-commit run --all-files
pre-commit install
```

`pre-commit install` also installs the pre-push gitleaks hook, which scans
the commits being pushed.

## Restoring

- **Everything** (lost database): restore mariadb01's backup chain; see the
  MariaDB restore runbook. This repository is not needed for that.
- **One rule or setting** (a bad edit): find the last good version with
  `git log -p -- alerting/alert-rules.yaml` and re-enter it in the Grafana UI.
- Do **not** load these files into Grafana's provisioning directory: that
  makes the rules provisioned and read-only in the UI, which reverses the
  decision that the database is authoritative.
