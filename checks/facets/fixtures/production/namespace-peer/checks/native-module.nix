{
  config,
  lib,
  nativeCheckMarker,
  options,
  pkgs,
  ...
}: {
  checks.native-check-module = lib.mkIf (config.testing.moduleProbes != []) (assert nativeCheckMarker == "owner-module-argument";
    assert options ? testing.moduleProbes;
    assert config.testing.moduleProbes == [{nativeCheckProbe = true;}];
      pkgs.runCommandLocal "facet-native-check-module" {} ''
        mkdir -p "$out"
        touch "$out/passed"
      '');
}
