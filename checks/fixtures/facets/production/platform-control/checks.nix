{
  omittedPackages,
  packages,
  pkgs,
  system,
  ...
}: {
  platform-omission = assert if system == "aarch64-darwin"
  then packages ? ai.devTools.unsupported-control
  else
    !(packages ? ai.devTools.unsupported-control)
    && builtins.elem ["ai" "devTools" "unsupported-control"] omittedPackages;
    pkgs.runCommandLocal "facet-platform-omission" {} ''
      mkdir -p "$out"
      touch "$out/passed"
    '';
}
