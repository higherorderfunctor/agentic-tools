{lib}: root: let
  entries = builtins.readDir root;
  directories = lib.filterAttrs (_: type: type == "directory") entries;
  hasModule = name: let
    children = builtins.readDir (root + "/${name}");
  in
    children."default.nix" or null == "regular";
in
  map (name: root + "/${name}/default.nix")
  (builtins.filter hasModule (builtins.attrNames directories))
