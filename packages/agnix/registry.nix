{repoPath, ...}: {
  checks.cacheHitParity = {
    agnix = {consumerPath = ["ai" "agnix"];};
    agnix-lsp = {consumerPath = ["ai" "lspServers" "agnix-lsp"];};
    agnix-mcp = {consumerPath = ["ai" "mcpServers" "agnix-mcp"];};
  };
  documentation.gitToolDescriptions.agnix = "Linter, LSP, and MCP for AI config files";
  update = {
    excludePatterns = ["^agnix-lsp$" "^agnix-mcp$"];
    targets.agnix = {
      file = repoPath ./packages/ai/agnix/package.nix;
      flags = ["--version" "skip"];
      git = "https://github.com/agent-sh/agnix.git";
      dependsOn = ["rust-overlay"];
    };
  };
}
