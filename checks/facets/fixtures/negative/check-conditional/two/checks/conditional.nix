{
  activateConditionalCheck,
  config,
  lib,
  options,
  pkgs,
  ...
}: {
  checks.shared = lib.mkIf (config.testing.moduleProbes != []) (
    assert activateConditionalCheck;
    assert options ? testing.moduleProbes;
      lib.mkForce (pkgs.runCommandLocal "facet-conditional-two" {} "touch $out")
  );
}
