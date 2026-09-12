## Naming Conventions

> **Last verified:** 2026-09-12 — owner recipes and their support files may be
> co-located; legacy overlay paths remain during the staged migration.

- Adopted packages:
  `packages/<owner>/packages/<namespace...>/<name>/package.nix`. Directory
  components below the inner `packages/` encode public namespaces. Source
  sidecars and patches live with their owner; retain the existing
  `<name>-package-lock.json` suffix while formatter/spelling excludes use it.
- Owner metadata: `packages/<owner>/registry.nix` contributes update/cache rows;
  derive mutable recipe paths with `repoPath ./relative/package.nix`.
- Legacy package overlays: `overlays/<group>/<name>.nix` (`mcp-servers`,
  `lsp-servers`, `git-tools`, `dev-tools`, `generic`; ungrouped ones sit at
  `overlays/<name>.nix`)
- Legacy per-package overlay support files:
  `overlays/<group>/<name>-<kind>.json` / `-<kind>.patch` beside the `.nix` —
  `-sources.json`, `-extracted.json`, `-package-lock.json`, `-<topic>.patch`.
  Flat, never a subdirectory: two configs (`treefmt.nix` global excludes,
  `devenv.nix` cspell excludes) are keyed on the `<name>-package-lock.json`
  glob.
- Server modules: `packages/<name>/modules/mcp-server.nix` — and only for
  servers this repo runs as a managed service (they are enumerated in
  `serverNames` in `packages/mcp-services/modules/homeManager/default.nix`). A
  client-launched stdio server is barrel-only: `packages/<name>/` with
  `lib/mk<Name>.nix` and no `modules/`. The top-level `modules/` directory named
  by earlier revisions of this list no longer exists.
- Skills: `packages/stacked-workflows/skills/<name>/SKILL.md`
- Published fragments: `packages/<pkg>/fragments/<name>.md`
- Dev fragments: `dev/fragments/<pkg>/<name>.md`
- config.update.targets keys use exported package names (matching the overlay
  attrset key)
- Exported packages: lowercase with hyphens
