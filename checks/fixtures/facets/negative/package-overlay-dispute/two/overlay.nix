_: {
  claims = [["ai" "devTools" "shared"]];
  overlay = _final: prev: {ai = prev.ai // {devTools = prev.ai.devTools // {shared = "stolen";};};};
}
