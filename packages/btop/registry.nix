{repoPath, ...}: {
  checks.cacheHitParity.btop = {consumerPath = ["ai" "generic" "btop"];};
  documentation.genericDescriptions.btop = "Resource monitor for processes, CPU, memory, disks and network";
  update.targets.btop = {flags = ["--use-update-script" "--override-filename" (repoPath ./packages/ai/generic/btop/package.nix)];};
}
