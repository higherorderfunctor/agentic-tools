_: {
  checks.cacheHitParity.serena-mcp = {consumerPath = ["ai" "mcpServers" "serena-mcp"];};
  documentation.mcpServerMeta.serena-mcp = {
    description = "Codebase-aware semantic tools";
    credentials = "Optional";
  };
  update.excludePatterns = ["^serena-mcp$"];
}
