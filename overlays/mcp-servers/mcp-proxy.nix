# mcp-proxy — override nixpkgs to pin a newer version from GitHub.
#
# nixpkgs uses python3Packages.buildPythonApplication with finalAttrs
# and GitHub source. We override src/version to track upstream.
#
# Instantiates `ourPkgs` from `inputs.nixpkgs` for cache-hit parity
# (see dev/fragments/overlays/overlay-pattern.md).
{
  inputs,
  final,
  ...
}: let
  ourPkgs = import inputs.nixpkgs {
    inherit (final.stdenv.hostPlatform) system;
  };
  inherit (ourPkgs) fetchFromGitHub;
  vu = import ../lib.nix;
  # httpx-auth has test failures in nixpkgs (jwt InsecureKeyLengthWarning)
  httpx-auth = ourPkgs.python3Packages.httpx-auth.overridePythonAttrs {doCheck = false;};

  rev = "153a96a61fde2bf5a23961c64a3dd96b5e385108";
  src = fetchFromGitHub {
    owner = "sparfenyuk";
    repo = "mcp-proxy";
    inherit rev;
    hash = "sha256-LeQc1AWq+/iGEePN8ouYjowEt63K23AoKiKktX2EziQ=";
  };
in
  ourPkgs.mcp-proxy.overridePythonAttrs (old: let
    # upstream: readPyprojectVersion @ pyproject.toml
    upstreamVersion = "0.12.0";
  in {
    version = vu.mkVersion {
      upstream = upstreamVersion;
      inherit rev;
    };
    inherit src;
    # v0.11.0 added httpx-auth dependency (not in nixpkgs' v0.10.0)
    dependencies =
      (old.dependencies or [])
      ++ [httpx-auth];
    nativeCheckInputs = with ourPkgs.python3Packages; [pytest pytest-asyncio];
    doInstallCheck = true;
    installCheckPhase = vu.mkMcpSmokeTest {bin = "mcp-proxy";};
    # Patch versionCheckHook's $version to drop our +<shortRev> suffix.
    # nixpkgs gave mcp-proxy a versionCheckHook in d6524aa (c043004 had
    # none), and the hook installs no phase of its own — it appends to
    # `preInstallCheckHooks`, so the `runHook preInstallCheck` that OPENS
    # mkMcpSmokeTest is what dispatches it. It matches the derivation's
    # `version` against `mcp-proxy --version`; ours carries the +<shortRev>
    # suffix the binary knows nothing about, so the hook `exit 2`s before
    # the smoke test body ever runs. `preVersionCheck` fires inside the hook
    # ahead of that comparison, so reassigning `version` there keeps the
    # check RUNNING, just against the string the binary actually prints.
    # Preferred over stripping the hook from `nativeInstallCheckInputs`
    # (oxlint's shape) or `dontVersionCheck`, both of which delete the
    # assertion instead of repairing it.
    preVersionCheck = ''
      version="${upstreamVersion}"
    '';
  })
