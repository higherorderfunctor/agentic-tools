let
  customizePackage = import ./withGrammars.nix;
in {
  ai = {
    mcpServers.mkSemble = import ./mkSemble.nix;
    semble =
      import ./integrations.nix
      // {
        inherit customizePackage;
        withGrammars = args: package: grammars: (customizePackage args) package grammars [];
      };
  };
}
