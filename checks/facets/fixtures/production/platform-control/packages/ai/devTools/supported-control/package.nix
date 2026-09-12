{pkgs}:
pkgs.runCommand "facet-supported-control" {
  messageFile = ./message.txt;
  sentinel = import ../../../../src/sentinel.nix;
} ''
  test "$sentinel" = "outside-package-tree"
  cp "$messageFile" "$out"
''
