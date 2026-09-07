# tsgolint — HEAD-tracked type-aware linting backend for oxlint, pinned
# against `ourPkgs` (this repo's nixpkgs) for cache-hit parity. Thin
# overrideAttrs of nixpkgs' tsgolint: swap src (main rev, submodules),
# version, and vendorHash; inherit the typescript-go submodule patch dance.
{
  inputs,
  final,
  ...
}: let
  ourPkgs = import inputs.nixpkgs {
    inherit (final.stdenv.hostPlatform) system;
  };
  vu = import ../lib.nix;

  rev = "86cffadb8a7285f7bb4a59538fa7b160a2dabd04";
  src = ourPkgs.fetchFromGitHub {
    owner = "oxc-project";
    repo = "tsgolint";
    inherit rev;
    hash = "sha256-NAbDg1AYzX+6J/Ad5qvbV9vYUOGhbrUSAUZCm6zVTBw=";
    fetchSubmodules = true;
  };
in
  ourPkgs.tsgolint.overrideAttrs (_finalAttrs: _prev: {
    version = vu.mkVersion {
      upstream = "0.25.0-unstable"; # newest tag base from Step 1
      inherit rev;
    };
    inherit src;
    vendorHash = "sha256-Qfo/HUxkpsT9lZJbAnLfOiCmqNn9qAnX45kRCSlE9lY=";
  })
