#!/usr/bin/env bash
# pr-watch-at-stop — Claude Code `Stop` hook. Refuses the hand-back while the
# PR this branch owns is unfinished, because prose could not make that happen.
#
# The rule it enforces is written in dev/fragments/monorepo/git-workflow.md:
# after opening or updating a PR the loop is the agent's, not the operator's.
# That rule was in the always-loaded steering and was ignored twice in one
# session AFTER the operator corrected it mid-session, which is what a hook is
# for: it does not depend on the model electing to remember anything.
#
# FAILS OPEN on every ambiguity. No upstream, no PR, no `gh`, a network fault,
# a timeout — all exit 0. A hook that blocks a hand-back because GitHub was
# briefly unreachable is worse than the failure it prevents, and unlike the
# lint validator this one cannot be satisfied by editing a file.
set -euETo pipefail
shopt -s inherit_errexit 2>/dev/null || :

payload="$(cat)"
get() { printf '%s' "$payload" | python3 -c "import sys,json;print(json.load(sys.stdin).get('$1',''))"; }

# The loop escape. Claude re-runs Stop hooks after a block, so without this the
# hook would refuse forever on a PR whose CI simply takes eight minutes.
[ "$(get stop_hook_active)" = "True" ] && exit 0

repo="$(get cwd)"
[ -n "$repo" ] && cd "$repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

command -v gh >/dev/null 2>&1 || exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[ -n "$branch" ] && [ "$branch" != "HEAD" ] || exit 0
# No upstream means nothing was pushed, so there is no PR to be waiting on.
git rev-parse --abbrev-ref "@{upstream}" >/dev/null 2>&1 || exit 0

head_sha="$(git rev-parse HEAD)"

# One call. `--json` on a branch with no PR exits non-zero, which is the
# common case and is not a fault.
pr_json="$(timeout 20 gh pr view --json number,isDraft,state,mergeStateStatus,statusCheckRollup,reviewThreads,headRefOid 2>/dev/null || true)"
[ -n "$pr_json" ] || exit 0

REPO_HEAD_SHA="$head_sha" python3 - "$pr_json" <<'PY'
import json, os, sys

try:
    pr = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

if pr.get("state") != "OPEN":
    sys.exit(0)

outstanding = []

# A conflicted PR schedules ZERO check runs, so an empty rollup here reads
# exactly like "CI has not started yet". Name it explicitly or the agent waits
# forever on runs that will never be queued.
if pr.get("mergeStateStatus") == "DIRTY":
    outstanding.append(
        "the PR is CONFLICTING, which means GitHub will schedule NO checks at "
        "all - rebase onto the base branch and force-push, do not wait"
    )

rollup = pr.get("statusCheckRollup") or []
running, failing = [], []
for c in rollup:
    name = c.get("name") or c.get("context") or "?"
    state = (c.get("status") or c.get("state") or "").upper()
    conclusion = (c.get("conclusion") or "").upper()
    if state in ("QUEUED", "IN_PROGRESS", "PENDING") and not conclusion:
        running.append(name)
    elif conclusion in ("FAILURE", "TIMED_OUT", "CANCELLED", "ACTION_REQUIRED") or state == "FAILURE":
        failing.append(name)

if failing:
    outstanding.append(
        "these checks are RED: %s - read the failing job's log, fix, push"
        % ", ".join(sorted(set(failing)))
    )
if running:
    outstanding.append(
        "these checks are still running: %s - arm a watcher whose exit wakes "
        "the session (a backgrounded `gh pr checks <n> --watch`), do not end "
        "the turn on a promise to check later"
        % ", ".join(sorted(set(running)))
    )

threads = ((pr.get("reviewThreads") or {}).get("nodes")) or pr.get("reviewThreads") or []
if isinstance(threads, list):
    unresolved = [t for t in threads if isinstance(t, dict) and t.get("isResolved") is False]
    if unresolved:
        outstanding.append(
            "%d review thread(s) are unresolved - they gate the merge; reply "
            "and resolve each in the same turn as its fix" % len(unresolved)
        )

if not outstanding:
    sys.exit(0)

print(json.dumps({
    "decision": "block",
    "reason": (
        "pr-watch-at-stop: PR #%s is not finished, and finishing it is yours "
        "rather than the operator's. Outstanding: %s. If a point above is "
        "genuinely not actionable, say so explicitly in your reply and stop "
        "again - this hook does not re-fire on the retry."
        % (pr.get("number"), "; ".join(outstanding))
    ),
}))
PY
exit 0
