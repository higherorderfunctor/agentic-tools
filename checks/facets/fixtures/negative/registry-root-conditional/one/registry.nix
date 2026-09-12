{
  facetOwner,
  facetSource,
  ...
}: {
  config.facetMock = {
    activate = true;
    entries.conditional-root = {
      owner = facetOwner;
      payload = "one";
      source = toString facetSource;
    };
  };
}
