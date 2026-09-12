# Coding-standards content package — reusable coding standard fragments.
# Derivation: pkgs.coding-standards
# passthru provides eval-time access to typed fragment attrsets.
{
  pkgs,
  fragmentsLib,
  repoPath,
  ...
}: let
  fragments = import ../../lib/fragments.nix {
    inherit fragmentsLib repoPath;
    inherit (pkgs) lib;
  };
in
  pkgs.runCommand "coding-standards" {} ''
    mkdir -p $out/fragments
    cp ${../../fragments}/*.md $out/fragments/
  ''
  // {
    passthru = {
      inherit fragments;
      presets = {
        all = fragmentsLib.compose {
          fragments = builtins.attrValues fragments;
          description = "All coding standards";
        };
        minimal = fragmentsLib.compose {
          fragments = [fragments.coding-standards fragments.commit-convention];
          description = "Minimal coding standards";
        };
      };
    };
  }
