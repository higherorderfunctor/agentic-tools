{pkgs, ...}: {
  checks.kiro-identity-splice =
    pkgs.runCommandLocal "kiro-identity-splice-check" {
      nativeBuildInputs = [pkgs.nodejs pkgs.python3];
    } ''
      python3 ${./kiro-identity-splice.py} ${../lib/kiro-identity-splice.py}
      touch "$out"
    '';
}
