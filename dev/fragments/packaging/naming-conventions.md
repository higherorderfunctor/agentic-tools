## Naming Conventions

> **Last verified:** 2026-09-12 — recipes, source sidecars, and registrations
> live with their owners.

- Package recipes:
  `packages/<owner>/packages/<namespace...>/<name>/package.nix`. Directory
  components below the inner `packages/` encode public namespaces. Source
  sidecars and patches live with their owner; retain the existing
  `<name>-package-lock.json` suffix while formatter/spelling excludes use it.
- Owner metadata: `packages/<owner>/registry.nix` contributes
  update/cache/documentation rows; derive mutable recipe paths with
  `repoPath ./relative/package.nix`.
- Owner source files: `sources.json`, `extracted.json`, `patches/`, and `src/`.
  Multiple release lines may use qualified sidecars such as `sources-10.json`.
  Package-specific extraction machinery belongs in the owner's
  `lib/packaging.nix` or `extract/` directory.
- Server modules: `packages/<name>/modules/mcp-server.nix` — and only for
  servers this repo runs as a managed service (they are enumerated in
  `serverNames` in `packages/mcp-services/modules/homeManager/default.nix`). A
  client-launched stdio server needs a public helper: `packages/<name>/` with
  `lib/mk<Name>.nix` and no `modules/`. The top-level `modules/` directory named
  by earlier revisions of this list no longer exists.
- Skills: `packages/stacked-workflows/skills/<name>/SKILL.md`
- Published fragments: `packages/<pkg>/fragments/<name>.md`
- Dev fragments: `dev/fragments/<pkg>/<name>.md`
- config.update.targets keys use exported package names (matching the overlay
  attrset key)
- Exported packages: lowercase with hyphens
