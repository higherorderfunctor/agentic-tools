{repoPath, ...}: {
  checks.cacheHitParity = {
    all-mcps = {consumerPath = ["ai" "mcpServers" "modelContextProtocol" "all-mcps"];};
    fetch-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "fetch-mcp"];
    filesystem-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "filesystem-mcp"];
    git-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "git-mcp"];
    memory-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "memory-mcp"];
    sequential-thinking-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "sequential-thinking-mcp"];
    time-mcp.consumerPath = ["ai" "mcpServers" "modelContextProtocol" "time-mcp"];
  };
  update.targets.filesystem-mcp = {
    file = repoPath ./packages/ai/mcpServers/modelContextProtocol/all-mcps/package.nix;
    flags = ["--version" "skip"];
    git = "https://github.com/modelcontextprotocol/servers.git";
  };
}
