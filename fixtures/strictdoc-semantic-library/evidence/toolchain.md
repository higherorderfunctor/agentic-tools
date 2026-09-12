# Clean toolchain delivery

<!-- cspell:ignoreRegExp /\b[0-9abcdfghijklmnpqrsvwxyz]{32}(?=-strictdoc-toolchain-source)/g -->

Verified 2026-09-11 against repository source revision
`8c6aa9bc648b00809502f765a860cbc2c79ac114` plus the retained source exporter.
This report covers delivery, not the proposed semantic rules.

## Refresh and native entrypoint

From this fixture directory:

```bash
bash bootstrap.sh
```

The script clears inherited `DEVENV_*`, `DIRENV_*`, and `SCRIBE_ROOT` variables,
builds the repository's `strictdoc-toolchain-source` package with
`--max-jobs 1`, replaces the ignored `.toolchain` directory, and runs
`devenv update library`. Re-run it after toolchain code or the repository
dependency lock changes. Restart a running fixture daemon after refreshing
implementation code.

The native configuration imports
`inputs.library.devenvModules.nix-agentic-tools`, selects
`inputs.library.packages.${pkgs.stdenv.hostPlatform.system}.strictdoc`, and
obtains the grammar DSL from `inputs.library.lib.ai.strictdocGrammar`. The
default installed source mode supplies the CLI, client, and daemon. The fixture
has no `flake.nix`.

Grammar declaration changes are a separate operation:
`devenv tasks run generate:sgra` renders `grammar.nix` to `grammar.sgra`; reload
or restart the daemon before relying on changed grammar. The consumer probes own
the lifecycle observations.

## Source boundary and pins

The built source is:

```text
/nix/store/bgqvk0jgdk208m6ydx53nqqp55qwdz81-strictdoc-toolchain-source
```

Its 33 implementation files match the repository source byte for byte: 19
runtime files selected by the existing `scribeSource.nix` allowlist and 14
explicitly selected grammar/module files. The only added files are a generated
public `flake.nix` entrypoint and a generated `flake.lock`: 35 files total. The
independent prototype manifest supplied the expected source file set for this
comparison; its grammar and document data were not reused.

The exported input contains no repository domain grammar values, semantic
engine, board assets, project corpus, fixture documents, or repository
configuration. The source exporter itself is also outside the exported consumer
source. This installs the existing public toolchain; it does not supply a
semantic backend.

The exporter derives the StrictDoc dependency subtree from the repository lock.
It traverses direct and follows dependencies and refuses follows that escape the
StrictDoc input. It does not maintain another copy of the upstream pins.

| Dependency           | Locked revision                            |
| -------------------- | ------------------------------------------ |
| Native devenv        | `190959a9a4bb52d4802f076a90c3c4e3aa2e6fa2` |
| Native shell nixpkgs | `c043004d1c6985732bcc1cbc5a9c9aecbbb4e0f0` |
| StrictDoc            | `7cf8183498ec87be531499230602df33523ed058` |
| StrictDoc's nixpkgs  | `f13ff45afd1bb73e640eaa08a7066dbed07e3238` |

The retained `devenv.lock` records the complete dependency graph. Offline
`nix flake metadata` resolved the generated clean input with
`--no-write-lock-file`; the entrypoint and lock remained byte-identical to the
built output.

## Refresh controls

Source-refresh controls ran against an isolated copy of only the approved
implementation files, exporter, and repository lock. They did not edit the live
implementation.

| Control                                                                 | Observed result                                                                                                |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Append a harmless comment to an allowed runtime source                  | New output `dzgwsv1z7jzck9vs8kqz2pzciirm76kz-strictdoc-toolchain-source`; changed bytes present; 2.589 seconds |
| Add an unlisted file alongside the isolated sources                     | Same changed output; unlisted file absent; 1.536 seconds                                                       |
| Restore the original allowed source bytes                               | Exact original output `bgqvk0jgdk208m6ydx53nqqp55qwdz81-strictdoc-toolchain-source`; 1.131 seconds             |
| Add a stale file and edit an allowed generated copy, then run bootstrap | Stale file removed and edited copy restored; all 33 source files matched again; 0.579 seconds                  |

The final bootstrap audit also confirmed that the input has exactly 35 files and
that the native library lock uses `.toolchain`.

A generated directory is intentional. In the measured alternative, using a Nix
output symlink caused devenv to record
`../../../../../../../../nix/store/bgqvk0jgdk208m6ydx53nqqp55qwdz81-strictdoc-toolchain-source`
as the library path. Replacing that symlink with an ignored directory yielded
the portable relative path `.toolchain`. The 33 generated implementation copies
are not tracked; their sources remain owned by the toolchain.

## Project separation

The parent project's document exclusion adds only
`fixtures/strictdoc-semantic-library/**`. The fixture itself binds alias `@repo`
to its generated grammar and includes `documents/**` and `grammar.sgra`, so the
parent exclusion does not remove the fixture's own data or grammar. Parent
corpus counts and fixture daemon behavior are verified separately through public
interfaces.

The consumer worker confirmed native `up`, `ping`, and `reload` after adding the
generated grammar to the include list: the loader seed produced one document and
zero nodes, and generated FOO help exposed the required FLAG choices. This
verifies the fixture configuration; the consumer's own evidence records
subsequent graph operations and lifecycle cleanup.

Formatting, shell syntax, and `git diff --check` passed for the infrastructure
changes. No commit or publication was performed by the infrastructure worker.
