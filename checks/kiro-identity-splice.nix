{pkgs, ...}:
pkgs.runCommandLocal "kiro-identity-splice-check" {
  nativeBuildInputs = [pkgs.nodejs pkgs.python3];
} ''
  python3 ${./kiro-identity-splice.py} ${../packages/kiro-cli/lib/kiro-identity-splice.py}
  touch "$out"
''
