{
  lib,
  pkgs,
  ...
}: {checks.shared = lib.mkForce (pkgs.runCommandLocal "facet-mixed-two" {} "touch $out");}
