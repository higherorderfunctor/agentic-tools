{
  facetOwner,
  facetSource,
  ...
}: {
  imports = [(import ./registry/conditional.nix {inherit facetOwner facetSource;})];
}
