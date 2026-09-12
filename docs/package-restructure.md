# Package restructure — retired planning index

**Retired 2026-09-12.** The implementation merged in
[PR #1633](https://github.com/higherorderfunctor/nix-agentic-tools/pull/1633),
completing the redesign tracked by
[#1019](https://github.com/higherorderfunctor/nix-agentic-tools/issues/1019).
[Repository ownership and layout](repository-layout.md) is the settled design
reference.

The old proposal, prototype gates, synthesis tasks, and rollout sequence are no
longer a backlog. In particular, the four-facet limit, root ownership of every
check, separate root overlay tree, and proposed grouping into roughly seven
slices do not describe the accepted implementation. Package-specific checks and
recipes now live with their owners; workspace checks and development tooling
remain at the root. Further directory regrouping requires a future redesign
request.

## Historical evidence

The
[original consolidated proposal](https://github.com/higherorderfunctor/nix-agentic-tools/blob/3510a5dbc816a1598e0ff0c357c0c237dc78b267/docs/package-restructure.md)
and its
[eight source documents](https://github.com/higherorderfunctor/nix-agentic-tools/blob/3510a5dbc816a1598e0ff0c357c0c237dc78b267/docs/archive)
remain available at the merged baseline in Git history. The source documents
were removed from the current tree so searches do not present competing
architectures:

- `ai-factory-collision-refactor-plan.md`
- `greenfield-package-shape.md`
- `mcp-servers-migration-plan.md`
- `mcp-servers-pilot-plan.md`
- `monorepo-restructure-assessment.md`
- `name-resolution-gap-analysis.md`
- `slice-architecture-assessment.md`
- `slice-nav-design.md`

For a local read of any retired file, use the baseline revision and its original
path:

```bash
git show 3510a5dbc816a1598e0ff0c357c0c237dc78b267:docs/package-restructure.md
```

The [ownership fragment](../dev/fragments/facets/package-ownership.md) carries
current composition contracts and tested pitfalls. Historical proposals are
evidence when investigating an old decision, not instructions to resume
implementation.
