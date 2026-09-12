## Project Overview

nix-agentic-tools is a Nix flake monorepo providing:

- **Stacked workflow skills** — SKILL.md files for stacked commit workflows
  using git-branchless, git-absorb, and git-revise
- **MCP server packages** — 12+ Model Context Protocol servers packaged as Nix
  derivations with typed settings and credential handling
- **Home-manager modules** — declarative configuration for Claude Code, Copilot
  CLI, Kiro CLI, stacked workflows, and MCP services
- **DevShell modules** — per-project AI tool configuration without home-manager
  (`mkAgenticShell`)
- **Git tool overlays** — git-absorb, git-branchless, git-revise

Skills work without Nix. Nix unlocks overlays, home-manager modules, and
devshell integration.

### Key Directories

```text
packages/<owner>/
  packages/ai/<namespace>/<name>/package.nix  Native binary recipes and roles
  lib/                  Public default.nix plus private factories/helpers
  modules/              Consumer Home Manager and devenv configuration
  registry.nix          Update, cache, documentation, and architecture metadata
  checks.nix, checks/   Owner checks and fixtures
  sources.json          Owner-local release pins (when needed)
  extracted.json        Measured CLI schemas (when needed)
  docs/, patches/, src/ Documentation and build support files
  fragments/, skills/  Published content (when applicable)
lib/                    Shared composition, AI module engines, packaging helpers
checks/                 Workspace validation and cross-owner integration
config/                 Workspace policy and shared option declarations/data
dev/                    Repo-only generation, tasks, scripts, skills, and guidance
devshell/               Standalone shell integration (mkAgenticShell)
flake.nix               Public assembly and repo outputs
devenv.nix              This repository's workspace shell
```
