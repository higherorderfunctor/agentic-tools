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
    factory-loadServer-kagi-mcp-from-package-dir = mkTest "loadServer-kagi-mcp-from-package-dir" (
      let
        mcpLib = import ../../../lib/mcp.nix {inherit lib;};
        serverDef = mcpLib.loadServer "kagi-mcp";
      in
        serverDef ? settingsOptions
        && serverDef.settingsOptions ? credentials
    );
  };
}
