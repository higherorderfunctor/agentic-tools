{repoPath, ...}: {
  checks.cacheHitParity.git-intel-mcp = {consumerPath = ["ai" "mcpServers" "git-intel-mcp"];};
  documentation.mcpServerMeta.git-intel-mcp = {
    description = "Git repository analytics";
    credentials = "None";
  };
  update.targets.git-intel-mcp = {
    file = repoPath ./packages/ai/mcpServers/git-intel-mcp/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/hoangsonww/GitIntel-MCP-Server.git";
  };
}
