# Hermetic branch-test for lib/pr-watch-at-stop.sh — the Stop hook that refuses
# a hand-back while this branch's PR is unfinished.
#
# It drives the REAL script against a STUB `gh`, so what is exercised is the
# decision logic and the fail-open paths, not GitHub. That split matters: the
# fail-open paths are the ones that cannot be tested against a live API at all
# (no `gh` on PATH, no upstream, a timeout), and they are also the ones whose
# regression is worst — a hook that blocks because the network hiccuped is
# worse than the failure it prevents, and unlike the lint validator this one
# cannot be satisfied by editing a file.
{pkgs, ...}: {
  checks.pr-watch-at-stop =
    pkgs.runCommandLocal "pr-watch-at-stop-check" {
      nativeBuildInputs = [pkgs.coreutils pkgs.git pkgs.python3 pkgs.shellcheck];
      src = ../../lib/pr-watch-at-stop.sh;
    } ''
      set -euETo pipefail
      shopt -s inherit_errexit 2>/dev/null || :

      outdir="$out"
      export HOME="$PWD/home"; mkdir -p "$HOME"
      git config --global user.email a@b.c
      git config --global user.name a
      git config --global init.defaultBranch main

      shellcheck --shell=bash "$src"

      mkdir -p bin repo
      REAL_PATH="$PATH"          # PATH without the gh stub, for the no-gh case below
      export PATH="$PWD/bin:$PATH"

      # --- stub gh: prints whatever PR_JSON holds, or fails like "no PR here" ---
      # Shebang resolved at build time — the nix sandbox has no /usr/bin/env.
      # printf, not a heredoc: Nix strips the common indentation from this string,
      # so a heredoc body plus a compensating `sed` de-indents twice and silently
      # emits a mangled script. That failure is invisible — the stub then exits
      # non-zero, the hook reads it as "no PR", and every allow-case passes
      # VACUOUSLY while only the block-cases fail.
      {
        command -v bash | sed 's|^|#!|'
        echo 'if [ -n "''${PR_JSON:-}" ]; then printf "%s" "$PR_JSON"; exit 0; fi'
        echo 'exit 1'
      } > bin/gh
      chmod +x bin/gh
      # Positive control on the stub itself, for exactly the reason above.
      PR_JSON=probe bin/gh | grep -qx probe

      cd repo
      git init -q .
      git commit -q --allow-empty -m init
      # An upstream must exist or the hook exits before ever calling gh.
      git branch -q -M feat/x
      git remote add origin ../fake.git
      mkdir -p ../fake.git && git -C ../fake.git init -q --bare
      git push -q origin feat/x 2>/dev/null
      git branch -q --set-upstream-to=origin/feat/x feat/x

      payload() { printf '{"stop_hook_active": %s, "cwd": "%s"}' "$1" "$PWD"; }

      run() { PR_JSON="$2" bash "$src" <<< "$(payload false)"; }

      expect_allow() {
        local name="$1" got; got="$(run "$name" "$2" || true)"
        if [ -n "$got" ]; then echo "FAIL [$name]: expected no block, got: $got" >&2; exit 1; fi
        echo "ok [$name] allowed"
      }
      expect_block() {
        local name="$1" json="$2" phrase="$3" got
        got="$(run "$name" "$json" || true)"
        if ! printf '%s' "$got" | grep -qF '"decision": "block"'; then
          echo "FAIL [$name]: expected a block, got: $got" >&2; exit 1; fi
        if ! printf '%s' "$got" | grep -qF "$phrase"; then
          echo "FAIL [$name]: block did not mention '$phrase': $got" >&2; exit 1; fi
        echo "ok [$name] blocked"
      }

      GREEN='{"number":1,"state":"OPEN","isDraft":false,"mergeStateStatus":"CLEAN","statusCheckRollup":[{"name":"test","status":"COMPLETED","conclusion":"SUCCESS"}],"reviewThreads":{"nodes":[]}}'

      # A finished PR must NOT block — without this the others pass for a hook that
      # always blocks, which would be indistinguishable and useless.
      expect_allow green "$GREEN"

      expect_block red '{"number":2,"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"name":"test","status":"COMPLETED","conclusion":"FAILURE"}],"reviewThreads":{"nodes":[]}}' 'checks are RED'

      # The case that actually failed in practice: the agent pushed and ended the
      # turn while CI was still running.
      expect_block running '{"number":3,"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"name":"build","status":"IN_PROGRESS"}],"reviewThreads":{"nodes":[]}}' 'arm a watcher'

      # A conflicted PR schedules ZERO checks, so an empty rollup reads exactly like
      # "CI has not started". The block must say rebase, not wait.
      expect_block conflicted '{"number":4,"state":"OPEN","mergeStateStatus":"DIRTY","statusCheckRollup":[],"reviewThreads":{"nodes":[]}}' 'CONFLICTING'

      expect_block threads '{"number":5,"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"SUCCESS"}],"reviewThreads":{"nodes":[{"isResolved":false}]}}' 'unresolved'

      # Not OPEN: nothing to finish.
      expect_allow merged '{"number":6,"state":"MERGED","mergeStateStatus":"CLEAN","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"FAILURE"}],"reviewThreads":{"nodes":[]}}'

      # --- fail-open paths, each proven with a payload that WOULD otherwise block ---
      RED='{"number":9,"state":"OPEN","mergeStateStatus":"BLOCKED","statusCheckRollup":[{"name":"t","status":"COMPLETED","conclusion":"FAILURE"}],"reviewThreads":{"nodes":[]}}'

      # loop guard: Claude re-runs Stop hooks after a block
      got="$(PR_JSON="$RED" bash "$src" <<< "$(payload true)" || true)"
      [ -z "$got" ] || { echo "FAIL [loop-guard]: blocked on retry: $got" >&2; exit 1; }
      echo "ok [loop-guard] allowed on stop_hook_active"

      # no PR for this branch (stub gh exits non-zero)
      got="$(bash "$src" <<< "$(payload false)" || true)"
      [ -z "$got" ] || { echo "FAIL [no-pr]: $got" >&2; exit 1; }
      echo "ok [no-pr] allowed"

      # no gh on PATH at all. Drop ONLY the stub directory — an earlier version
      # built a minimal PATH by hand and left out bash itself, so the hook never
      # ran and the case passed for the wrong reason.
      command -v bash >/dev/null   # positive control: bash IS reachable on REAL_PATH
      got="$(PATH="$REAL_PATH" PR_JSON="$RED" bash "$src" <<< "$(payload false)" || true)"
      [ -z "$got" ] || { echo "FAIL [no-gh]: $got" >&2; exit 1; }
      echo "ok [no-gh] allowed"

      # not a git work tree
      got="$(PR_JSON="$RED" bash "$src" <<< "$(printf '{"stop_hook_active": false, "cwd": "/"}')" || true)"
      [ -z "$got" ] || { echo "FAIL [no-repo]: $got" >&2; exit 1; }
      echo "ok [no-repo] allowed"

      mkdir -p "$outdir"; touch "$outdir/ok"
    '';
}
