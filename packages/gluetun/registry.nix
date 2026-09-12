{repoPath, ...}: {
  # The one platform-gated row. gluetun's `internal/routing` uses
  # Linux-only x/sys/unix constants, so lib/facets/repository.nix omits the
  # ATTRIBUTE on non-Linux rather than only restricting meta.platforms —
  # and this row has to say the same thing, or the check aborts on
  # aarch64-darwin looking up a package that is not there.
  checks.cacheHitParity.gluetun = {
    consumerPath = ["ai" "generic" "gluetun"];
    platforms = import ./packages/ai/generic/gluetun/platforms.nix;
  };
  documentation.genericDescriptions.gluetun = "VPN client for multiple providers (Linux only)";
  update.targets.gluetun = {flags = ["--use-update-script" "--override-filename" (repoPath ./packages/ai/generic/gluetun/package.nix)];};
}
