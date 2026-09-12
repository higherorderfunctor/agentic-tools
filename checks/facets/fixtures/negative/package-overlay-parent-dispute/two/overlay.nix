_: {
  claims = [["ai" "devTools"]];
  overlay = _final: _prev: throw "ownership must fail before this overlay is called";
}
