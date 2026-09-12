{pkgs, ...}: {
  checks = {
    placeholder = pkgs.runCommandLocal "facet-invalid-owner" {} "touch $out";
  };
}
