{repoPath, ...}: {
  checks.cacheHitParity.effect-mcp = {consumerPath = ["ai" "mcpServers" "effect-mcp"];};
  documentation.mcpServerMeta.effect-mcp = {
    description = "Effect-TS documentation";
    credentials = "None";
  };
  update.targets.effect-mcp = {
    file = repoPath ./packages/ai/mcpServers/effect-mcp/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/tim-smart/effect-mcp.git";
  };
}
