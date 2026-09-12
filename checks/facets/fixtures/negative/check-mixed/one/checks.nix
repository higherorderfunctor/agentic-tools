{pkgs, ...}: {checks.shared = pkgs.runCommandLocal "facet-mixed-one" {} "touch $out";}
