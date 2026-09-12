## Package ownership and native composition

> **Last verified:** 2026-09-12 — all owners use native package, library,
> module, and registry composition.

An owner directory groups the implementation, checks, and declarative metadata
for a package. Public package namespaces come from the directory components
below `packages/<owner>/packages/`; the outer owner name has no namespace
meaning. Renaming that owner does not rename its public packages.

The shared engine indexes sources before evaluation, then uses native mechanisms
for each contribution: recursive nixpkgs package scopes, overlay composition,
raw backend module imports, and typed `evalModules` registries. Ownership checks
run before module priority can hide a competing definition. Shared namespace
containers are legal; package leaves and conflicting prefixes are exclusive.

`registry.nix` contributes update/cache metadata, documentation descriptions,
and owner-specific architecture fragment registrations. Use the injected
`repoPath ./relative/source.nix` to declare a mutable repository source path. It
derives the path from the actual owner location and removes Nix string context;
hardcoding `packages/<owner>/...` would defeat relocation. Root modules remain
responsible for workspace policy. Every owner is discovered; no central package
list or opt-in registry predicate controls discovery.

Registry claim discovery isolates each contributor's definitions while
evaluating conditions and imported arguments against the combined `config`,
`options`, and `_module.args`. The same context applies to root policy. A
registry key whose presence depends on another owner therefore remains visible
to collision checks, even when a competing definition uses `mkForce`.

`checks.nix` returns an attribute set of derivations from the supplied context.
Adding a package check requires only an owner edit. Root and owner check names
share an exclusive claim boundary, so neither can silently overwrite the other.
Root checks cover composition and repository invariants, including the
real-owner relocation control. Keep backend-specific module paths raw so Home
Manager and devenv evaluate them independently with their own arguments.

Three evaluation boundaries are easy to break:

- **Discover overlay root names before forcing package values.** Computing
  overlay attribute names from a realized package world forces `final.stdenv`
  while nixpkgs is still discovering its fixed point, producing infinite
  recursion. Use indexed package paths and static ordinary-overlay claims for
  root names; realize values only beneath those names. Ordinary overlay claim
  paths must be independent of package evaluation.
- **Validate package values when accessed.** Index and collision checks may
  inspect all paths, but must not evaluate unrelated recipes. A package missing
  from a deliberately older test pin cannot prevent access to another package.
  Full flake validation still forces every exported derivation.
- **Platform filtering changes the discovery path type.** `builtins.path`
  returns a context-bearing string. Native discovery therefore passes string
  recipe paths for filtered trees. Remap both path and string recipes to the
  original owner tree, discarding context only from the relative suffix before
  appending it to the original path. Otherwise supported siblings lose relative
  imports outside the filtered tree or change derivation identity.

Namespace merging stops at derivations. A generic recursive attrset merge would
retain fields from a previous package while replacing its `drvPath`, creating a
hybrid package. Preserve namespace neighbors and replace package leaves whole.

Package recipes receive this flake's pinned `pkgs`, independently of the
consumer pin. Shared packaging helpers arrive through `packageLib`; package
implementation files should not encode a relative route back to the repository
root. Consumer policy, including the existing unfree guard, belongs at overlay
assembly rather than inside a package's source/build recipe. The composer guards
only owned package leaves with `lib/facets/unfree-guard.nix`, preserving
existing namespace neighbors and avoiding duplicate wrappers.

`lib/default.nix` contributes public helpers, using native module options with
raw leaf values. Functions retain their `functionArgs`; option declarations,
option types, and callable attrsets are atomic values whose internals must stay
lazy. Private helpers beside that entry point are not exported automatically.
Backend directories require `default.nix`; ordinary `.nix` sidecars in
`modules/` remain private to the backend modules that import them.

The flat flake package projection comes from indexed leaf basenames. It rejects
collisions, including workspace outputs, before constructing the final attrset.
A nested namespace is available through the overlay while every leaf remains a
derivation at the flat flake boundary. Both flake and devenv use the same
repository composer; document generation uses its package-independent registry.
