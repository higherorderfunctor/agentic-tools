{repoPath, ...}: {
  checks.cacheHitParity.mcp-language-server = {consumerPath = ["ai" "mcpServers" "mcp-language-server"];};
  documentation.mcpServerMeta.mcp-language-server = {
    description = "LSP-to-MCP bridge";
    credentials = "None";
  };
  update.targets.mcp-language-server = {
    file = repoPath ./packages/ai/mcpServers/mcp-language-server/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/isaacphi/mcp-language-server.git";
  };
}
