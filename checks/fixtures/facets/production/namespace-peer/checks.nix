{
  lib,
  packages,
  pkgs,
  ...
}: {
  native-package-namespaces = assert packages.ai.devTools."literal.name".drvPath != packages.ai.devTools.literal.name.drvPath;
  assert lib.isDerivation packages.ai.mcpServers.modelContextProtocol.fixture_mcp;
    pkgs.runCommandLocal "facet-native-package-namespaces" {
      nativeBuildInputs = [packages.ai.devTools.alpha-tool packages.ai.devTools.peer-tool];
    } ''
      test -e ${packages.ai.devTools.alpha-tool}/passed
      test -e ${packages.ai.devTools.peer-tool}/passed
      mkdir -p "$out"
      touch "$out/passed"
    '';
}
