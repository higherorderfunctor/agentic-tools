{
  facetOwner,
  facetSource,
}: {
  config,
  lib,
  nativeRegistryMarker,
  options,
  ...
}: {
  config.facetMock.entries = lib.optionalAttrs config.facetMock.activate {
    conditional-child = assert options ? facetMock.activate; {
      owner = facetOwner;
      payload = nativeRegistryMarker;
      source = toString facetSource;
    };
  };
}
