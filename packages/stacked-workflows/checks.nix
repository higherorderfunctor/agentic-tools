{
  imports = [./checks/module-eval.nix];
  testing.moduleProbes = [{ai.programs.stacked-workflows.enable = true;}];
}
