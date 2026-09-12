{
  facetOwner,
  facetSource,
  ...
}: {
  config.facetMock = {
    activate = true;
    entries.shared = {
      owner = facetOwner;
      payload = "one";
      source = toString facetSource;
    };
  };
}
