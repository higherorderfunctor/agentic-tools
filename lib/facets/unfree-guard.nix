# Keep the cached build pinned while enforcing the consumer's license policy.
final: drv: let
  license = drv.meta.license or {};
  isUnfree =
    if builtins.isList license
    then builtins.any (item: !(item.free or true)) license
    else !(license.free or true);
in
  if isUnfree
  then
    final.symlinkJoin {
      inherit (drv) name version;
      paths = [drv];
      meta = drv.meta or {};
      passthru = drv.passthru or {};
    }
  else drv
