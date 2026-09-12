_: {
  claims = [
    ["ai" "gitReviseObserved"]
  ];
  overlay = _final: prev: {
    ai =
      prev.ai
      // {
        gitReviseObserved = "${prev.ai.seed}:${prev.ai.alpha}:${prev.ai.gitTools.git-revise.fixtureSentinel}";
      };
  };
}
