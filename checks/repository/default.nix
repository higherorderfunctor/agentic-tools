{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [./formatting.nix];
  checks = (import ../../config/repo-validation.nix {inherit lib pkgs;}).mkCiChecks {
    gitHooksRun = inputs.git-hooks.lib.${pkgs.stdenv.hostPlatform.system}.run;
    src = ../..;
  };
}
