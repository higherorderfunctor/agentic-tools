{pkgs, ...}: {
  imports = [./checks/copilot-wrapper-argv.nix ./checks/module-eval.nix];
  testing.homeManagerAiPackages.copilot-cli = pkgs.writeShellScriptBin "copilot" ''
    set -euETo pipefail
    shopt -s inherit_errexit 2>/dev/null || :
    exec true
  '';
}
