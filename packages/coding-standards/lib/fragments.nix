{
  fragmentsLib,
  lib,
  repoPath,
}: let
  names = map (lib.removeSuffix ".md") (builtins.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name)
    (builtins.readDir ../fragments)
  ));
in
  lib.genAttrs names (name:
    fragmentsLib.mkFragment {
      text = builtins.readFile (../fragments + "/${name}.md");
      description = "coding-standards/${name}";
      source = repoPath (../fragments + "/${name}.md");
      priority = 10;
    })
