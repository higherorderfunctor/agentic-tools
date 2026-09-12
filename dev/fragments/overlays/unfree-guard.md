## Unfree Package Guard (`ensureUnfreeCheck`)

> **Last verified:** 2026-09-12 — one composer guards only owned package leaves,
> preserving inherited neighbors.

### The problem

Nix overlays that build unfree packages with `ourPkgs` (pinned nixpkgs,
`config.allowUnfree = true`) silently bypass the consumer's unfree preference.
The nixpkgs unfree check (`pkgs/stdenv/generic/check-meta.nix`) fires at
`mkDerivation` eval time, bound to the nixpkgs instance's config — not the
consumer's. Once a permissive `ourPkgs` produces the derivation, the consumer
gets the pre-evaluated result with no check.

### The solution

`lib/facets/unfree-guard.nix` implements the shared guard. It inspects
`meta.license.free` (including lists of licenses), passes free derivations
through unchanged, and wraps unfree derivations with the consumer's
`final.symlinkJoin`. The wrapper carries the original metadata, passthru, name,
and version, with the pinned derivation as its sole `paths` entry.

Repository facet assembly applies it to indexed, supported package leaves after
overlay composition. It must not traverse namespace neighbors inherited from
`prev`: those packages may already carry a guard and would acquire a second
wrapper.

### How it works

1. `ourPkgs` (overlay-internal, `allowUnfree = true`) builds the real
   derivation. CI pushes it to cachix.
2. `ensureUnfreeCheck` inspects `meta.license.free`. If unfree, wraps in
   `final.symlinkJoin` (consumer's nixpkgs) carrying `meta = drv.meta`. The
   consumer's `check-meta.nix` fires on the wrapper — standard error if they
   haven't set `allowUnfree`.
3. If free, returns the derivation unwrapped (zero overhead).
4. Applied at assembly — newly discovered package leaves are automatically
   guarded.

### Cache-hit parity is preserved

The unfree check is purely eval-time (`check-meta.nix`). It does NOT affect
derivation hashes. The wrapper's dependency on the real derivation (from
`ourPkgs`) has the same store path CI built, so cachix serves it.

### Consumer UX

- Consumer without `allowUnfree` -- standard nixpkgs unfree error
- Consumer with `allowUnfree = true` -- works, cached from cachix
- Consumer with `allowUnfreePredicate` -- works for allowed pkgs
- Free packages -- no wrapper, pass through, zero overhead

### This pattern is novel

No existing community solution was found (researched 2026-04-10):

- numtide/nixpkgs-unfree: complete fork, bypasses consumer pref
- Discourse advice: "just set allowUnfree" when importing
- Official nixpkgs/Hydra: does NOT build unfree at all

Our wrapper pattern appears unique in the Nix ecosystem. Document any changes to
it thoroughly.

### When adding new packages

No manual per-package work needed. The `guard` function wraps everything at the
output level. Just ensure your new package's `meta.license` is set correctly —
the guard reads it to decide whether to wrap.

### Packages currently unfree

- `claude-code` (proprietary)
- `copilot-cli` / `github-copilot-cli` (proprietary)
- `kiro-cli` / `kiro-gateway` (proprietary)

All other packages (MCP servers, git tools, agnix) are free and pass through the
guard unwrapped.
