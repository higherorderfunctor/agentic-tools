# End-to-end module contracts; the shared harness discovers every backend.
# cspell:ignore batchmode sembleignore
{
  lib,
  harness,
  ...
}: let
  inherit (harness) evalDevenv evalHm harnessNames mkTest;
in {
  checks = {
    # ── Stacked-workflows: skills + router, user-global (HM) + project (devenv) ──
    # The HM module installs the unprefixed stack-* skills + skill-routing rule
    # user-global; the devenv module mirrors them project-local. References are
    # bundled as REAL files inside each skill dir (deref'd at build).

    # Default disabled — the portable program enable defaults to false.
    module-sws-default-disabled = mkTest "sws-default-disabled" (
      let
        result = evalHm {};
      in
        !result.config.ai.programs.stacked-workflows.enable
        && !(result.options.stacked-workflows ? enable)
    );

    # ── Where these contributions land ────────────────────────────────────
    #
    # The skill packages write the PER-RUNTIME pools (`ai.<runtime>.skills`,
    # `ai.<runtime>.rules`), never the root ones. The tests below assert
    # both halves of that, and the second half is the one worth having: a root
    # package write would silently fan out beyond package runtime ownership, so a
    # regression could still deliver every skill and pass a presence-only test.
    #
    # They iterate `harnessNames` (the shared registry) rather than sampling one
    # runtime, so a sixth runtime is covered the day it is added.

    # Devenv scope: enable -> every runtime's pool gets the unprefixed stack-*
    # skills, and the root pool gets none of them.
    module-sws-devenv-enable-sets-ai-skills = mkTest "sws-devenv-enable-sets-ai-skills" (
      let
        result = evalDevenv {ai.programs.stacked-workflows.enable = true;};
        expected = ["stack-fix" "stack-plan" "stack-split" "stack-submit" "stack-summary" "stack-test"];
        runtimeHasAll = runtime:
          lib.all (skill: result.config.ai.${runtime}.skills ? ${skill}) expected;
      in
        lib.all runtimeHasAll harnessNames
        && !(result.config.ai.skills ? stack-fix)
    );

    # Devenv scope: the router rule lands in every supporting runtime's pool and
    # not in the root pool.
    module-sws-devenv-enable-sets-ai-rules = mkTest "sws-devenv-enable-sets-ai-rules" (
      let
        result = evalDevenv {ai.programs.stacked-workflows.enable = true;};
        ruleRuntimes = builtins.filter (runtime: result.options.ai.${runtime} ? rules) harnessNames;
        runtimeHasOne = runtime: result.config.ai.${runtime}.rules ? stacked-workflows-router;
      in
        lib.all runtimeHasOne ruleRuntimes
        && !(result.config.ai.rules ? stacked-workflows-router)
    );

    # HM (user-global) scope: enable -> every runtime's pool gets the unprefixed
    # stack-* skills, so each enabled CLI installs them to ~/.claude/skills etc.
    # This is the scope-revert (previously the HM module was git-config only).
    module-sws-hm-enable-sets-ai-skills = mkTest "sws-hm-enable-sets-ai-skills" (
      let
        result = evalHm {ai.programs.stacked-workflows.enable = true;};
        expected = ["stack-fix" "stack-plan" "stack-split" "stack-submit" "stack-summary" "stack-test"];
        runtimeHasAll = runtime:
          lib.all (skill: result.config.ai.${runtime}.skills ? ${skill}) expected;
      in
        lib.all runtimeHasAll harnessNames
        && !(result.config.ai.skills ? stack-fix)
    );

    # HM (user-global) scope: enable -> the skill-routing rule lands in every
    # supporting runtime's pool.
    module-sws-hm-enable-sets-ai-rules = mkTest "sws-hm-enable-sets-ai-rules" (
      let
        result = evalHm {ai.programs.stacked-workflows.enable = true;};
        ruleRuntimes = builtins.filter (runtime: result.options.ai.${runtime} ? rules) harnessNames;
        runtimeHasOne = runtime: result.config.ai.${runtime}.rules ? stacked-workflows-router;
      in
        lib.all runtimeHasOne ruleRuntimes
        && !(result.config.ai.rules ? stacked-workflows-router)
    );

    # Package rules are defaults, so a consumer can replace the router for one
    # runtime without creating a definition conflict or affecting its siblings.
    module-sws-consumer-rule-override-wins = mkTest "sws-consumer-rule-override-wins" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          ai.claude.rules.stacked-workflows-router.text = "Consumer router.";
        };
      in
        result.config.ai.claude.rules.stacked-workflows-router.text
        == "Consumer router."
        && result.config.ai.codex.rules.stacked-workflows-router.text != "Consumer router."
    );

    # B4 program negation controls the package's actual per-runtime pool writes.
    # Disabling Codex removes both its skills and router while sibling runtimes
    # continue inheriting the portable enable.
    module-sws-runtime-program-negation = mkTest "sws-runtime-program-negation" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          ai.codex.programs.stacked-workflows.enable = false;
        };
      in
        result.config.ai.claude.skills ? stack-fix
        && result.config.ai.claude.rules ? stacked-workflows-router
        && !(result.config.ai.codex.skills ? stack-fix)
        && !(result.config.ai.codex.rules ? stacked-workflows-router)
    );

    # Runtime overrides control runtime pool writes only. A runtime-only enable
    # cannot activate the machine-wide Git companion when the portable program
    # remains disabled.
    module-sws-git-preset-requires-portable-enable = mkTest "sws-git-preset-requires-portable-enable" (
      let
        result = evalHm {
          ai.codex.programs.stacked-workflows.enable = true;
          stacked-workflows.gitPreset = "minimal";
        };
      in
        !(result.config.programs.git.settings ? branchless)
        && result.config.ai.codex.skills ? stack-fix
    );

    # Conversely, a runtime negation does not retract Git configuration selected
    # by the portable program enable.
    module-sws-runtime-negation-keeps-git-preset = mkTest "sws-runtime-negation-keeps-git-preset" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          ai.codex.programs.stacked-workflows.enable = false;
          stacked-workflows.gitPreset = "minimal";
        };
      in
        result.config.programs.git.settings ? branchless
        && !(result.config.ai.codex.skills ? stack-fix)
    );

    # Git config applies when preset is "minimal".
    module-sws-git-config-minimal = mkTest "sws-git-config-minimal" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          stacked-workflows.gitPreset = "minimal";
        };
        gitSettings = result.config.programs.git.settings;
      in
        (gitSettings ? branchless)
        && (gitSettings ? pull)
        && (gitSettings ? rebase)
    );

    # Git config applies when preset is "full" (includes extended settings).
    module-sws-git-config-full = mkTest "sws-git-config-full" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          stacked-workflows.gitPreset = "full";
        };
        gitSettings = result.config.programs.git.settings;
      in
        (gitSettings ? branchless)
        && (gitSettings ? diff)
        && (gitSettings ? fetch)
        && (gitSettings ? push)
        && (gitSettings ? revise)
    );

    # Git config NOT set when preset is "none".
    module-sws-git-config-none = mkTest "sws-git-config-none" (
      let
        result = evalHm {
          ai.programs.stacked-workflows.enable = true;
          stacked-workflows.gitPreset = "none";
        };
        gitSettings = result.config.programs.git.settings;
      in
        !(gitSettings ? branchless)
    );

    # References are bundled as REAL files inside each skill dir (deref'd at
    # build) — NOT written as separate .claude/references/* files anymore.
    # This guards the dangling-symlink regression: the skill's references must
    # resolve to real, present files.
    module-sws-skill-references-resolve = mkTest "sws-skill-references-resolve" (
      let
        result = evalDevenv {ai.programs.stacked-workflows.enable = true;};
        skillPath = result.config.ai.claude.skills.stack-fix;
      in
        builtins.pathExists "${skillPath}/SKILL.md"
        && builtins.pathExists "${skillPath}/references/git-absorb.md"
        && builtins.pathExists "${skillPath}/references/git-branchless.md"
    );
  };
}
