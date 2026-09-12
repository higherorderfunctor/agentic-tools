{pkgs, ...}: {
  checks.discovered = pkgs.runCommandLocal "discovered-workspace-check" {} "touch $out";
}
