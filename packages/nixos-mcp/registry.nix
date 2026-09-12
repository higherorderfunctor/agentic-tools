_: {
  checks.cacheHitParity.nixos-mcp = {consumerPath = ["ai" "mcpServers" "nixos-mcp"];};
  documentation.mcpServerMeta.nixos-mcp = {
    description = "NixOS and Nix documentation";
    credentials = "None";
  };
  update.excludePatterns = ["^nixos-mcp$"];
}
