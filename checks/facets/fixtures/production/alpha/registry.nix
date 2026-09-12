{
  facetOwner,
  facetSource,
  ...
}: {
  config = {
    _module.args.nativeRegistryMarker = "registry-module-argument";
    facetMock = {
      activate = true;
      entries.alpha = {
        owner = facetOwner;
        payload = "alpha";
        source = toString facetSource;
      };
    };
  };
}
