# Factory contracts for this owner or shared primitive.
{
  lib,
  pkgs,
  harness,
  ...
}: let
  inherit (import ../../../lib/testing/factory-harness.nix {inherit lib pkgs harness;}) mkTest;
in {
  checks = {
    factory-loadServer-gitlab-mcp-from-package-dir = mkTest "loadServer-gitlab-mcp-from-package-dir" (
      let
        mcpLib = import ../../../lib/mcp.nix {inherit lib;};
        serverDef = mcpLib.loadServer "gitlab-mcp";
      in
        serverDef ? settingsOptions
        && serverDef.settingsOptions ? pat
    );

    factory-gitlab-mcp-has-package-module = mkTest "gitlab-mcp-has-package-module" (
      builtins.pathExists ../modules/mcp-server.nix
    );
  };
}
