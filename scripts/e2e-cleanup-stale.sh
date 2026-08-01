#!/usr/bin/env bash
# Crash-cleanup preamble for the live-e2e runner (#47/#50): a crashed run
# leaves an open branch and PR in template-e2e — successful runs self-clean
# via delete_branch_on_merge, crashed ones never reach merge at all. Run this
# as the first step of every e2e run, not as a separate scheduled sweep
# (#42's decision comment, Q5): self-healing, every future run cleans up
# after any prior crash, no cron/machinery.
#
# THRESHOLD_MINUTES is provisional — set generously above a rough estimate
# of one run's real duration (render + push + draft-gate wait + ready-flip +
# check-poll + merge), since #48's live run hadn't executed yet when this was
# written. Revisit once real run durations are observed (#50's own acceptance
# criterion), tightening it so a stale run is swept sooner without risking a
# still-running one getting swept out from under itself.
#
# usage: GH_TOKEN=<token-with-write-on-template-e2e> scripts/e2e-cleanup-stale.sh
set -euo pipefail

REPO="carpet-stain/template-e2e"
THRESHOLD_MINUTES=30
BRANCH_PATTERN='^e2e/'

: "${GH_TOKEN:?GH_TOKEN must be set to a token with contents+pull_requests write on $REPO}"

cutoff=$(date -u -d "-${THRESHOLD_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ)

# gh pr list's own --search can't filter by branch-name-prefix + age together,
# so pull the candidate set (number, branch, age) and filter with real jq
# (gh's own --jq has no --arg passthrough) — same shape as the
# render-then-verify scripts' preference for one clear pass over a chain of
# flag-encoded conditions.
mapfile -t stale < <(
  gh pr list -R "$REPO" --state open --json number,headRefName,createdAt |
    jq -r --arg pattern "$BRANCH_PATTERN" --arg cutoff "$cutoff" '
      .[] | select(.headRefName | test($pattern)) | select(.createdAt < $cutoff)
      | "\(.number) \(.headRefName)"'
)

if [ "${#stale[@]}" -eq 0 ]; then
  echo "e2e-cleanup-stale: no stale e2e/* PRs older than ${THRESHOLD_MINUTES}m in $REPO"
  exit 0
fi

for entry in "${stale[@]}"; do
  number=${entry%% *}
  branch=${entry#* }
  echo "e2e-cleanup-stale: sweeping stale PR #$number ($branch) in $REPO"
  gh pr close "$number" -R "$REPO" --delete-branch
done
