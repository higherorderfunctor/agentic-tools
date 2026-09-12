{pkgs, ...}: {
  _module.args.activateConditionalCheck = true;
  testing.moduleProbes = [{activate = true;}];
  checks.shared = pkgs.runCommandLocal "facet-conditional-one" {} "touch $out";
}
