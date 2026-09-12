## Config Parity

Three configuration methods exist with the same rough interface:

- **lib/** — manual functions for consumers wiring config directly
- **HM modules** (`modules/`) — declarative home-manager (system-level)
- **devenv modules** (`modules/devenv/`) — project-local dev shell

If a feature can be configured in HM, it must also be configurable in devenv and
vice versa. Gaps between methods are bugs unless a capability has an explicit
backend exclusion.

`ai.strictdoc` is explicitly devenv-only: it configures a project's document
toolchain, so Home Manager is out of scope. Its package barrel contributes to
`devenvModules.nix-agentic-tools`; `checks/options-doc.nix` requires its public
option reference and excludes only this namespace from the otherwise exact
`ai.*` option-name/type comparison. `ai.strictdoc.scribeSource` defaults to
`"installed"`: CLI, client, daemon and source readers come from an explicit Nix
source allowlist, independently of the document root. No project semantics model
or board assets are packaged. `"project"` selects live project scripts and the
repository-specific board; this repository opts into it for development. The
optional semantics command remains lazy and reports an unavailable engine when
the invoking environment supplies none. Grammar rendering happens at evaluation;
`generate:sgra` writes those rendered bytes in a separate task invocation.

Surfaces to keep aligned across all three methods: skills,
instructions/steering, MCP servers, LSP servers, settings, hooks, agents,
environment variables, permissions.

The `ai.*` module (both HM and devenv) provides a unified interface that fans
out shared surfaces to enabled ecosystems (Claude, Codex, Copilot, Kimchi, Kiro)
with ecosystem-specific translation. A surface without a lossless native mapping
is an explicit exclusion, not a silent no-op.
