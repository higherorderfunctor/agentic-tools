{repoPath, ...}: {
  checks.cacheHitParity.git-revise.consumerPath = ["ai" "gitTools" "git-revise"];
  update.targets.git-revise = {
    file = repoPath ./packages/ai/gitTools/git-revise/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/mystor/git-revise.git";
  };
}
