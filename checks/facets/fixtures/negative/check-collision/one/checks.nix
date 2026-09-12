{pkgs, ...}: {
  checks = {
    shared = pkgs.runCommandLocal "facet-shared-check-one" {} "touch $out";
  };
}
