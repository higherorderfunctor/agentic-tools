# Kiro v3 scope probes (hooks / skills / agents / global)

Preserved, manually-runnable reproducers for **what Kiro v3 actually loads and
fires** — per surface (hooks, skills, agents), per scope (workspace vs global),
and, load-bearing for the factory, **real files vs store symlinks**. Originally
verified against `kiro-cli 2.13.0` on 2026-07-23; steering re-verified against
`2.21.4` on 2026-09-12, where the answer CHANGED — see below.

> **Status: knowledge-capture, not the regression fixture.** These scripts drive
> a live Kiro TUI and spend the operator's real Kiro account, so they are
> **manual** reproducers, not CI tests. The hardened, hermetic regression
> fixture (nmt-integrated) is tracked as `oi-probe-fixtures-port` in the
> converge-agentic-foundations plan (phase P4). This directory exists so that
> work — and anyone re-checking a finding on a Kiro bump — starts from a working
> harness instead of reconstructing it.
>
> The older `docs/plans/steering-symlink-probe/run-probe.sh` is the
> steering-specific ancestor and is now **stale**: it passes `--tui --v3` by
> hand (the wrapper injects them now → clap aborts on the double) and uses the
> headless path (which skips the hook engine). `probe-steering.sh` supersedes it
> (the steering drop was re-verified 2026-07-23 via `/context show`).

## Run

```bash
./setup-rig.sh              # build the hook rig under /var/tmp/nat-kiro-probe
./probe-hooks.sh           # workspace + global hooks (real vs symlink) via the live TUI
./probe-global-realhome.sh # real-file vs symlinked GLOBAL hooks at the real ~/.kiro/hooks (additive, trap-cleaned)
./probe-skills-agents.sh   # skills + agents (real / symlinked-file / symlinked-dir), self-contained
./probe-steering.sh        # workspace steering (real vs symlink) via /context show
```

Requires `tmux` and `kiro-cli` on PATH, plus a logged-in Kiro account.

## These spend real credits — pin the cheap model

Every script here drives a live Kiro TUI against the operator's real account.
The scripts now pass `--model gpt-5.6-luna` explicitly; **keep that flag on any
probe you add.** Without it a run inherits `chat.defaultModel` from
`~/.kiro/settings/cli.json`, which is a per-operator setting and is currently
the most expensive tier available.

The multipliers move, so this file does not copy them.
`kiro-cli chat --list-models` prints the live table, and the reference copy
lives in `dev/references/kiro-workflows.md`. At the time of writing luna is the
cheapest listed tier and the default in use was 22x its rate, which is the whole
reason for the flag.

`/context show` and the other slash-command signals are local, so a probe that
only enumerates should cost little regardless — but the flag costs nothing to
carry and protects the probes that do take a real turn.

## Steering: the answer changed between 2.13.0 and 2.21.4

`probe-steering.sh` originally recorded that v3 DROPS a symlinked steering file.
Re-run on `2.21.4` on 2026-09-12, it **FOLLOWS** — both the real control and the
symlink are listed by `/context show`.

That matters because symlink-vs-copy delivery for Kiro steering rides on it, and
because the repo moved steering back to a symlink sink after a spike on 2.18.1
without a recorded re-verification afterwards. This re-run closes that gap for
workspace scope at 2.21.4.

**Global steering was measured at 2.13.0 and has NOT been re-verified at
2.21.4.** It is not unmeasured — the 2026-07-23 round covered both scopes and
found both dropped (see the historical section below). What is missing is a
re-run at the current pin, and no SAVED script covers the global path: that
round used an ad-hoc real-home probe. Re-verifying means splicing
`probe-steering.sh`'s method onto `probe-global-realhome.sh`'s scope.

Since workspace flipped from drop to follow, global probably flipped too — same
loader — but "probably" is not a delivery decision. Treat the global path as
unverified at 2.21.4 rather than as either answer.

## Four harness bugs (the expensive part — do not re-hit)

1. **`timeout … script -qec "…"` deadlocks in a live terminal.** `script` tries
   to arbitrate the controlling tty and never opens its typescript → exit 124,
   no output. Run from a no-controlling-tty context (`setsid`, or an agent
   shell), or drive the TUI with `tmux` instead.
2. **The `kiro-cli` wrapper appends `--tui --v3` unconditionally.** Passing them
   by hand doubles `--tui` and clap aborts (`cannot be used multiple times`).
   Pass only your own args; let the wrapper add the engine flags. (Fixed to be
   idempotent in PR #463, but a reproducer should still not pass them.)
3. **`--no-interactive` runs the model but SKIPS the hook engine.** v3 hooks
   fire only in the live TUI, per turn. A headless one-shot answers the prompt
   yet fires nothing — even the real-file control. You must drive a real
   interactive turn (hence `tmux`).
4. **The `/hooks` modal eats typed input as its filter.** Send the chat turn
   FIRST, capture `fired.log`, THEN open `/hooks` — otherwise your prompt lands
   in the modal's search box and no turn runs.

## Methodology

- **Drive a real TUI with tmux.** `tmux new-session -d … kiro-cli chat` launches
  a real pty; `tmux send-keys` injects the prompt and slash commands;
  `tmux capture-pane` reads the screen. This runs the interactive-only hook path
  with no human at the keyboard.
- **Two signals.** _Firing_: hooks append a marker to `fired.log` when they run
  (ground truth). _Loading_: on-screen enumerations — `/hooks` (modal list),
  `/agent` (list/switch agents), `/context show` (lists steering + skill files).
  There is **no** `/skills` command.
- **Isolation.** `KIRO_HOME=<rig>/home/.kiro` redirects config/hooks/settings
  while leaving the auth DB (under `~/.local/share`) intact. Never set `HOME` or
  `XDG_DATA_HOME` (that kills the Kiro auth DB). Rigs live outside `$HOME`.
- **KIRO_HOME does NOT relocate the global-hooks path.** The 2.13.0 global-hooks
  loader reads the real `$HOME/.kiro/hooks`, so `probe-global-realhome.sh` tests
  global hooks by placing an additive, trap-cleaned probe there.

## Rig layout (`setup-rig.sh`)

```
/var/tmp/nat-kiro-probe/
  home/.kiro/hooks/probe-global.json      GLOBAL-*   (reached via KIRO_HOME)
  home/.kiro/settings/cli.json  = {}
  work/  (git repo)
    .kiro/hooks/probe-local.json          LOCAL-*    (real workspace file = control)
    .kiro/hooks/probe-symlink.json  ->  src/probe-symlink.json   SYMLINK-*
  fired.log                               markers appended here when a hook fires
```

## Historical findings (kiro-cli 2.13.0) — steering rows SUPERSEDED

> Everything below is the 2026-07-23 round against 2.13.0. The two steering rows
> no longer describe current behaviour: workspace steering was re-measured on
> 2.21.4 and now FOLLOWS symlinks, and global steering has not been re-run.
> Hooks, agents and skills rows are untouched by that re-run and stand as
> recorded.

**v3 symlink handling is surface-specific — not universal:**

| Surface              | Symlinked file | Real file | How observed                |
| -------------------- | -------------- | --------- | --------------------------- |
| Hooks (workspace)    | **dropped**    | loads     | `/hooks` + `fired.log`      |
| Hooks (global)       | **dropped**    | loads     | `probe-global-realhome`     |
| Steering (workspace) | **dropped**    | loads     | `/context show`             |
| Steering (global)    | **dropped**    | loads     | `/context show` (real-home) |
| Agents               | **follows**    | loads     | `/agent`                    |
| Skills               | **follows**    | loads     | `/context show`             |

Steering was re-verified directly 2026-07-23 (`probe-steering.sh` + an additive
real-home global probe): the symlinked steering file is absent from
`/context show` on both scopes while the real one loads — confirming
`kirodotdev/Kiro#9787` independently of the stale `run-probe.sh`. **That is the
2.13.0 result and the workspace half is now superseded** — see the 2.21.4
section above. The global half stands only as a 2.13.0 observation. Skill
dir-symlinks and file-symlinks both loaded; the model reading files via
`fs_read` can mask the loader's behavior, so trust `/context show`, not a "can
you see skill X" question.

**Consequences for the factory, as understood at 2.13.0:** hooks and steering
must be delivered as **real files** (copy materialization); agents and skills
may stay cheap symlinks. **The steering half of that no longer holds at 2.21.4**
— workspace steering follows symlinks, so the symlink sink is correct for it,
and the global path is unverified rather than known-broken. Hooks are unaffected
by the re-run and still require copy. Global hooks read the real `~/.kiro/hooks`
and honor real files — so `autoMemory`, delivered there as a **store symlink**
on the live system, is silently dropped under v3; the on-branch real-file
delivery restores it once activated.
