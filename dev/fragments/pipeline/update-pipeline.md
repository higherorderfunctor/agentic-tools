## Update Pipeline Architecture

> **Last verified:** 2026-09-12 — adopted owners contribute update rows through
> their registry modules and derive repository paths from their source location.
> The deterministic resolver searches legacy overlays and co-located recipes.
>
> **Settled — do not relitigate.** Gating the PR on a passing build was tried
> and rejected. It parks every later bump of that input behind one broken
> package — measured on PR #1527, red from 2026-09-07 to 2026-09-09 on a single
> `versionCheckHook` mismatch — and it makes the sweep, not the PR list, the
> thing a human has to poll. The Renovate shape is: the bot writes the change,
> branch CI judges it.
>
> Full lineage: `git show ed5898b1:dev/fragments/pipeline/update-pipeline.md`.

### Execution model: ninja DAG

The update pipeline uses ninja as a DAG executor. A nix expression
(`config/generate-update-ninja.nix`) reads `flake.lock` and
`config.update.targets` (the `.#updateTargets` flake output) to emit
`.update.ninja` with dependency edges (e.g., agnix and git-absorb depend on
`rust-overlay` input being updated first, via their `dependsOn`).
`update-init.sh` runs once as the root target to clean stale state (abort stuck
git ops, delete old `update/*` branches, clear the report file). Every package
depends on that initialization plus its explicit `dependsOn` predecessors. It
does not depend on the separate nixpkgs or nix-update input targets: their
branches never feed state into the package worktree, so those edges would only
serialize independent work.

Targets fall into three categories:

- **Inputs** (`update-input.sh <name>`) — `nix flake update <name>` in a
  worktree, then `devenv update` to sync `devenv.lock`. The `llm-agents` input
  additionally regenerates Semble's committed upstream-template snapshot from a
  separate derivation. It does not rewrite the human-reviewed content hashes, so
  a changed template reaches the update PR but fails its coverage check until
  the local derivative is reviewed.
- **Packages** (`update-pkg.sh <name> [flags] [git-url]`) — runs `nix-update` in
  a worktree, optionally preceded by a rev bump for main-tracking packages. The
  Beads binary target is the one grouped package: its `passthru.updateScript`
  runs independent Beads and Dolt release updaters in sequence, so either
  upstream can move while the target still produces one branch, one build of
  `.#beads`, and one PR. The paired Dolt remains a nested package dependency,
  not a second registry row or Ninja edge. The `treefmt-nix` input target waits
  for the other isolated targets, then the final `update-report` target runs
  `update-report.sh` to print a summary grouped by status. There is no
  base-checkout format/build finalizer because it cannot observe changes
  committed only on target branches.

### Worktree isolation

Every update target runs in its own **ephemeral** git worktree under
`$WORKTREES_DIR/update-<name>/` — a binned temp root (default
`${TMPDIR:-/tmp}/nat-update-worktrees`, override `NAT_UPDATE_WORKTREES_DIR`)
deliberately OUTSIDE the flake root: devenv/Nix enumerates all untracked +
gitignored files under the flake root on every shell entry
(`git ls-files --others`; cachix/devenv#257, #2042), so in-tree worktrees were
re-scanned on every `direnv reload`. Each worktree checks out a named branch
`update/<name>` reset to the current branch HEAD. `.pre-commit-config.yaml` is
symlinked from the main tree so hooks work in worktrees. Worktrees are torn down
on exit (`teardown_worktree`) and any registration stranded by a crash or wiped
temp is reaped by `git worktree prune` in `update-init.sh`, so nothing persists
between runs.

After each target finishes its update + build verification in the worktree, it
leaves the resulting commits on its named branch and emits a single report line.
The pipeline never merges those branches itself; the CI workflow's PR-creation
step pushes each `update/<name>` branch that has commits ahead of the base SHA
and opens (or updates) one PR per dependency.

### Rev bump flow (main-tracking packages)

For packages that track a git repo's HEAD (no tagged releases), `update-pkg.sh`
receives the repo URL as a trailing argument:

1. `git ls-remote <url> HEAD` fetches the latest commit SHA.
2. The overlay file to bump comes from the package's declared
   `config.update.targets.<name>.file`, read via
   `nix eval --raw .#updateTargets.<name>.file`. Every main-tracking package
   declares one, so this is the live path; `resolve_overlay_file`
   (`dev/scripts/resolve-overlay-file.sh`) is a retained safety-net fallback
   that searches legacy overlays and owner package trees for the single `.nix`
   recipe pinning this upstream by matching the fetch block's identity — either
   `fetchFromGitHub { owner = "<owner>"; repo = "<repo>"; }` or
   `fetchgit { url = "…github.com/<owner>/<repo>.git"; }` — and requiring an
   inline 40-hex revision and **exactly one** match. 0 or >1 matches ⇒ the
   target is reported `HELD BACK` (never a silent guess).
   `checks.update-targets-parity` asserts the declared `file` is byte-identical
   to what the resolver would print, so the two paths can never diverge. `sed`
   then replaces the old `rev` in that resolved file.
3. `nix flake prefetch github:<owner>/<repo>/<new-rev>` fetches the new source
   hash.
4. `sed` replaces the old `hash` in the overlay `.nix` file.
5. `git commit` creates a commit with the rev + src hash change.
6. `nix-update --version skip` runs to update dependency hashes (cargo, pnpm,
   vendor, etc.). If changes occur, they amend into the existing commit.

If the rev is unchanged (already at latest), steps 1-6 are skipped entirely and
the target reports NO UPDATES.

**Why the resolver is deterministic.** Step 2 replaced an earlier
`grep -rl "<repo-basename>" | head -1`, which matched any overlay merely naming
the basename (e.g. `effect-mcp.nix`'s "Mirrors context7-mcp.nix." comment) and
raced on `head -1`'s early pipe close. On 2026-07-15 that wrote context7's HEAD
rev into effect-mcp's `tim-smart/effect-mcp` fetch block, pinning a nonexistent
commit → source 404 → red CI (and silently froze packages whose mis-resolved
file had no `rev`, e.g. mcp-proxy). The `checks.update-targets-parity` flake
check now asserts every main-tracking target resolves to exactly one overlay
carrying an inline rev AND that its declared `file` matches that resolver
output, so the class fails at PR time rather than mid-pipeline.

### config.update.targets (single source of truth)

The per-package update config lives in `config.update.targets`, an option-merged
registry every package contributes a row to. It replaced the flat, top-level
`config/update-matrix.nix`, which was dissolved.

- **`lib/update.nix`** — a plain module declaring `options.update.targets`, an
  `attrsOf (submodule { file; flags; git; dependsOn; })`, plus the sibling
  `options.update.excludePatterns`. `file` is a repo-relative POSIX path STRING
  (never a Nix path literal), `null` for binary packages; `git` is the upstream
  URL for main-tracking rev-bump, `null` for binary packages; `dependsOn` names
  DAG predecessors (e.g. `["rust-overlay"]`). For the reference submodule shape,
  read the sibling option-merged registries `lib/fragments-registry.nix` and
  `lib/checks.nix` — same `attrsOf (submodule …)` declaration, same
  central-contribution split. Both are tracked. This bullet used to cite
  `private/slice-fixture/lib/concerns.nix` instead; `/private/` is gitignored
  local working material, so that pointer resolves for nobody but its author.
  The fixture itself is described in `docs/package-restructure.md`.
- **`config/update-targets.nix`** — the legacy contribution: each remaining
  legacy row EXCEPT effect-mcp, plus the `excludePatterns` list carried over
  from the dissolved matrix. Rows split into main-tracking (a `git` URL and a
  non-null `file`) and binary (`git = null`, `file = null`). **No total is
  written here on purpose.** A hardcoded one rots by construction — this bullet
  carried "29 packages — 16 main-tracking + 13 binary" long after the sweep had
  grown past it. Derive it instead:

  ```bash
  nix eval --json .#updateTargets --apply 'ts: with builtins;
    let n = attrNames ts; in {
      total = length n;
      mainTracking = length (filter (k: ts.${k}.git != null) n);
    }'
  ```

  `.#updateTargets` is the merged registry, so that count includes effect-mcp's
  co-located row; this file carries one fewer. It is not the size of a sweep
  either — the ninja DAG adds one Inputs target per root flake input, read from
  `flake.lock`, so a sweep's PR ceiling is targets PLUS inputs. The binary rows
  all pass `--use-update-script`, optionally with `--override-filename <path>`;
  that second flag is what lets several attributes of one upstream (`pnpm_10`,
  `pnpm_11`) each own a file and a sidecar.

- **`overlays/mcp-servers/effect-mcp.update.nix`** — effect-mcp's own row,
  co-located with the overlay it bumps:
  `config.update.targets.effect-mcp = { file = "overlays/mcp-servers/effect-mcp.nix"; flags = ["--version" "skip"]; git = "https://github.com/tim-smart/effect-mcp.git"; }`.
  The sidecar carries its own `git` URL; `resolve_overlay_file` skips
  `*.update.nix` files (update metadata, never source-pinning overlays), so the
  URL does not make it a second match for `tim-smart/effect-mcp`.
- **`packages/<owner>/registry.nix`** — adopted owners carry their own rows.
  `file = repoPath ./packages/<namespace>/<package>/package.nix` derives the
  mutable repository-relative path from the module's actual location, so an
  owner-directory rename needs no central registration edit.
- **`.#updateTargets`** — selected from `lib/facets/repository.nix`'s native
  module evaluation. It merges discovered owner registries with workspace policy
  and legacy rows; ownership validation rejects competing package keys before
  priorities can hide them. `excludePatterns` remains available to the
  completeness check through the same result.
- **Consumers** — `config/generate-update-ninja.nix` reads `updateTargets` for
  the ninja DAG (flags space-joined, git, and `dependsOn` → `update-<dep>`
  edges); `update-pkg.sh` reads `.#updateTargets.<name>.file` for the rev-bump
  target.
- **`checks/update-targets-parity.nix`** — the permanent bidirectional CI gate
  (and sole update-target check; the former `overlay-target-resolution.nix`
  folded into it). Packages → targets: every versioned flake package must have a
  same-name row, share a derivation, source, or update script with a targeted
  package, declare an existing flake input through `passthru.updateFlakeInput`,
  carry a non-empty `passthru.updateTargetExempt` reason, or match an explicit
  `excludePatterns` exemption. The first CI run proved the reverse direction by
  finding two previously unrecorded cases: `git-branchless` is owned by its
  flake input. (The other historical exemption, the repository-local
  `kiro-memory-distiller`, was removed on 2026-09-01 — the shape it illustrated,
  an in-repo package with no upstream release to sweep, has no current
  instance.) Targets → overlays: every main-tracking target (with a `git` URL)
  must declare a non-null `file` equal to
  `resolve_overlay_file(<git>, overlays, packages)`, and the resolved overlay
  must carry an inline 40-hex `rev`. A positive control removes the real,
  uniquely sourced `context7-mcp` row in memory and requires that its package
  become uncovered; this proves the reverse direction can fail without mutating
  the registry on disk.

### Report format

Every target writes exactly one line to `.update-report.txt`:

- `UPDATED: <name> | <version-detail>` — successfully updated.
- `NO UPDATES: <name>` — already at latest.
- `HELD BACK: <name> | <version-detail> (<reason>)` — the update was found but
  could not be WRITTEN: the lock update failed, a hash could not be derived, the
  formatter errored, or the commit failed. A failing BUILD is deliberately not
  on this list — see "What holds a target back" below.

`update-report.sh` sorts entries by status and prints a summary.

### What holds a target back

One rule: **hold back only when the PR cannot be written.**

| Failure                             | PR writable?                                  | Outcome                                        |
| ----------------------------------- | --------------------------------------------- | ---------------------------------------------- |
| `nix flake update` fails            | no — no lock to commit                        | `HELD BACK`                                    |
| a dependency hash cannot be derived | no — the PR needs a value that does not exist | `HELD BACK`                                    |
| formatter errors                    | no — tree left non-canonical                  | `HELD BACK`                                    |
| `git add` / `git commit` fails      | no                                            | `HELD BACK`                                    |
| everything written, build fails     | **yes**                                       | `UPDATED` — red PR, `::warning::` in the sweep |

The last row is the whole point. A bump whose hashes all resolved is a complete,
committable change; that it does not build is a fact about the code, and the six
required checks on the PR are what report it. Withholding the PR there converts
a visible red check into an invisible line in a sweep log.

**Errexit must stay ARMED inside a target body, and that is a property of the
SHAPE.** Bash disables `errexit` for any command whose status it tests — an `if`
or `while` condition, a `!` negation, or the left operand of `||`/`&&` — and
that suppression reaches inside a subshell and overrides a `set -e` written
there. `( … ) || rc=$?` is not a fix either; the `||` puts the subshell back in
a tested context. Only a standalone subshell works:

```bash
target_rc=0
set +e
(
  set -euETo pipefail
  shopt -s inherit_errexit 2>/dev/null || :
  …
)
target_rc=$?
set -e
```

Under the old `if ! ( … ); then` shape every bare command in a target body fell
through to the trailing `git commit`, whose success became the target's status.
A nixpkgs bump whose build verification FAILED therefore shipped as `UPDATED` —
sweep 34351134945 logged exactly that, with zero `HELD BACK:` lines in 12,274
lines of log, and it had been doing so since at least 69c00ef2 (2026-04-13).

`checks/target-subshell-shape.nix` fails the build if the shape regresses, and
carries a positive control so it cannot pass vacuously when a body is renamed or
removed. **That gate is the rule; this paragraph only explains it.** The rule
lived as prose first and was broken twice within two days of being written, each
time caught by a reviewer rather than by a tool — shellcheck has no diagnostic
for it. The explicit `exit` calls still in those bodies are now belt-and-braces,
not the mechanism.

### Key files

| File                                         | Role                                                            |
| -------------------------------------------- | --------------------------------------------------------------- |
| `checks/update-targets-parity.nix`           | Flake check: declared `file` == resolver output + inline rev    |
| `config/generate-update-ninja.nix`           | Generates `.update.ninja` DAG from flake.lock + updateTargets   |
| `config/update-targets.nix`                  | Legacy `config.update.targets` rows and workspace exclusions    |
| `dev/scripts/resolve-overlay-file.sh`        | Deterministic overlay resolution (fetch-block identity + guard) |
| `dev/scripts/update-common.sh`               | Shared functions (worktree, version, report, colors)            |
| `dev/scripts/update-init.sh`                 | Pipeline initialization (clean stale state)                     |
| `dev/scripts/update-input.sh`                | Per-input update script                                         |
| `dev/scripts/update-pkg.sh`                  | Per-package update script (rev bump + nix-update)               |
| `dev/scripts/update-report.sh`               | Report printer                                                  |
| `lib/update.nix`                             | Declares `config.update.targets` (the option declaration)       |
| `overlays/mcp-servers/effect-mcp.update.nix` | effect-mcp's co-located update-target contribution row          |
| `.github/workflows/update.yml`               | CI workflow (Renovate-style per-dependency PRs)                 |
