{repoPath, ...}: {
  checks.cacheHitParity.arkenfox = {consumerPath = ["ai" "generic" "arkenfox"];};
  documentation.genericDescriptions.arkenfox = "Hardened Firefox user.js preference set";
  update.targets.arkenfox = {flags = ["--use-update-script" "--override-filename" (repoPath ./packages/ai/generic/arkenfox/package.nix)];};
}
