_: {
  claims = [["ai" "devTools" "shared" "child"]];
  overlay = _final: _prev: throw "ownership must fail before this overlay is called";
}
