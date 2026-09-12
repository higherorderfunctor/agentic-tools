{
  lib,
  pkgs,
  ...
}: let
  discover = import ../../lib/testing/discover.nix {inherit lib;};
  world = (import ../../lib/facets.nix {inherit lib;}).realizeChecks {
    context = {inherit lib pkgs;};
    index.owners = [];
    rootModules = discover ./discovery-fixtures;
  };
in {
  checks.facet-check-discovery = assert builtins.attrNames world.checks == ["discovered"];
    pkgs.runCommandLocal "facet-check-discovery" {} ''
      test -e ${world.checks.discovered}
      touch "$out"
    '';
}
