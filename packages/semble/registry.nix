{facetOwner, ...}: {
  checks.cacheHitParity = {
    semble = {consumerPath = ["ai" "semble"];};
    semble-mcp = {consumerPath = ["ai" "mcpServers" "semble-mcp"];};
  };
  documentation = {
    aiCliDescriptions.semble = "Local semantic and lexical code-search CLI";
    mcpServerMeta.semble-mcp = {
      description = "Local semantic and lexical code search";
      credentials = "None";
    };
  };
  # semble: program-factory integration, customization, cache ownership, and
  # the shared HM/devenv backend contract.
  fragments.categories.semble = {
    scopes = ["packages/${facetOwner}/**"];
    sources = [
      {
        location = "package";
        name = "semble";
        dir = facetOwner;
      }
    ];
  };
}
