{repoPath, ...}: {
  checks.cacheHitParity.catppuccin-btop = {consumerPath = ["ai" "generic" "catppuccin-btop"];};
  documentation.genericDescriptions.catppuccin-btop = "Catppuccin theme files for btop";
  update.targets.catppuccin-btop = {flags = ["--use-update-script" "--override-filename" (repoPath ./packages/ai/generic/catppuccin-btop/package.nix)];};
}
