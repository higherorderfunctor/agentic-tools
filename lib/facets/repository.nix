{
  inputs,
  registryModules,
  root,
  systems,
}: let
  inherit (inputs.nixpkgs) lib;
  facets = import ../facets.nix {inherit lib;};
  index = facets.index {
    facetsDir = root + "/packages";
    # Migration adapter: owners opt in by carrying their declarative registry.
    # Remove the predicate when the remaining legacy owners have migrated.
    includeOwner = path: builtins.pathExists (path + "/registry.nix");
  };
  repoPath = path:
    assert lib.hasPrefix "${toString root}/" (toString path);
      builtins.unsafeDiscardStringContext (lib.removePrefix "${toString root}/" (toString path));
  registryFor = claimPath:
    facets.realizeRegistry {
      inherit claimPath index;
      modules = [../checks.nix ../update.nix] ++ registryModules;
      specialArgs = {inherit inputs repoPath;};
    };
  update = (registryFor ["update" "targets"]).config.update;
  cacheHitParity = (registryFor ["checks" "cacheHitParity"]).config.checks.cacheHitParity;
  packageWorlds = lib.genAttrs systems (system:
    facets.realizePackages {
      inherit index inputs system;
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      scopeArgs.packageLib = import ../../overlays/lib.nix;
    });
  # Overlay attribute names must be available before the nixpkgs fixed point
  # can supply stdenv/system. Discover the outer namespace without realization.
  packageRoots =
    lib.unique (map (claim: builtins.head claim.keyPath)
      (lib.concatMap (owner: owner.contributions.packages) index.owners));
in {
  inherit cacheHitParity index packageWorlds update;
  overlay = final: prev: let
    system = final.stdenv.hostPlatform.system;
    context = {
      inherit inputs lib system;
      inherit (packageWorlds.${system}) packages;
    };
    ordinaryRoots = lib.concatMap (owner: let
      claim = owner.contributions.overlay;
      imported = import claim.source;
      contribution =
        if builtins.isFunction imported
        then imported context
        else imported;
    in
      if claim == null
      then []
      else map builtins.head contribution.claims)
    index.owners;
    guard = import ./unfree-guard.nix final;
    world = facets.realizeOverlay {
      inherit context index;
      packageWorld = packageWorlds.${system};
    };
    # Guard only owned package leaves; namespace neighbors may already have
    # been guarded by another overlay and must not acquire a second wrapper.
    guarded = lib.updateManyAttrsByPath (map (claim: {
        path = claim.keyPath;
        update = guard;
      })
      packageWorlds.${system}.eligibleClaims) (world.overlay final prev);
  in
    lib.genAttrs (lib.unique (packageRoots ++ ordinaryRoots)) (name: guarded.${name} or (prev.${name} or {}));
  checksFor = {rootChecks ? {}, ...} @ context:
    lib.mapAttrs (_: claim: claim.value) (facets.realizeChecks {
      inherit index rootChecks;
      rootSource = root + "/checks";
      context = builtins.removeAttrs context ["rootChecks"] // {inherit inputs lib;};
    });
  moduleImports = backend: facets.moduleImports {inherit backend index;};
}
