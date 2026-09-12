{pkgs, ...}: {
  checks = {
    placeholder = pkgs.runCommandLocal "facet-unsupported-metadata" {} "touch $out";
  };
}
