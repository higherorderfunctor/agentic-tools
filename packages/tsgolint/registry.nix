{repoPath, ...}: {
  # tsgolint src uses fetchSubmodules (typescript-go). The rev-bump pre-step's
  # `nix flake prefetch` writes a submodule-less src hash, but nix-update then
  # self-corrects it — its `outputHash=""` src rebuild respects fetchSubmodules,
  # yielding the right hash (+ vendorHash) before the build-verify. Validated
  # 2026-07-21: standard main-tracking flow works, no bespoke updateScript.
  checks.cacheHitParity.tsgolint = {consumerPath = ["ai" "devTools" "tsgolint"];};
  documentation.devToolDescriptions.tsgolint = "Type-aware linting backend for oxlint (typescript-go)";
  update.targets.tsgolint = {
    file = repoPath ./packages/ai/devTools/tsgolint/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/oxc-project/tsgolint.git";
  };
}
