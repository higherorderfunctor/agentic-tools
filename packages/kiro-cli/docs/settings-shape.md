## Kiro settings: a flat format with object values, and where the key stops

> **Last verified:** 2026-09-12 — source paths and ownership guidance follow
> native package assembly.

`~/.kiro/settings/cli.json` is FLAT: its keys are dotted strings, not nested
objects. `nativeSettings` lets you write the nested Nix that reads naturally and
`flattenKiroSettings` lowers it:

```nix
{ mcp.loadedBefore = true; chat.enableTangentMode = true; }
# -> {"mcp.loadedBefore": true, "chat.enableTangentMode": true}
```

The trap is that **flat keys do not imply scalar values.** `chat.modelDefaults`
is one key whose value is an object of per-model records. Attrset shape alone
cannot tell that apart from two more levels of grouping, so a walk that flattens
everything writes

```json
{ "chat.modelDefaults.claude-opus-5.effort": "high" }
```

which kiro never matches — it compares the literal key it reads. Nothing errors;
the setting simply does not exist. That held on BOTH backends, so the option was
not a devenv-scope problem, it was unusable.

### The boundary is extracted, not guessed

`aiCommon.flattenDotKeysUntil` takes a list of dotted paths that are complete
setting keys and stops recursing the moment the accumulated path is one of them.
`mkKiro.nix` passes `kiroSettingKeys` — the union of two measured lists from
`packages/kiro-cli/extracted.json`:

- `settingKeys`: the bundle's own `SCREAMING -> "dotted.key"` registry, 52 keys
  at 2.21.1, all `chat.*`.
- `workspaceOverridableSettings`: the workspace allowlist, which adds 21 keys
  the registry omits — the whole `toolSearch.*`, `compaction.*` and
  `knowledge.*` families, plus ten `chat.*` keys including
  `chat.enableTangentMode`. That last one is the extractor's own PROBE anchor,
  which makes it the sharpest available evidence that the registry is not the
  settings universe: the probe the allowlist scan keys off is itself absent from
  the registry scan.

Neither alone covers the format, which is why the sidecar reports them
separately and the union is taken at the consumer. Both come out of one scan of
the chat binary (`kiroSettingsExtractScript`) because they share the registry
regex, and a second pass would be a second place for it to drift.

`flattenDotKeys` is now `flattenDotKeysUntil []` — the historical
flatten-everything behavior, unchanged for anything that does not pass a
boundary.

### What this does and does not fix

It fixes the WRITTEN SHAPE. A key still has to be one kiro honors at that scope:
under devenv the workspace allowlist applies on top, so `chat.modelDefaults`
works there and `telemetry.enabled` does not. See
[`workflow-gating.md`](workflow-gating.md) for that half.

It also removes a misleading diagnostic. The devenv workspace guard reports the
WRITTEN key, so before the boundary existed it named
`chat.modelDefaults.claude-opus-5.effort` as a rejected key — true, but the
fault was the flattener walking past the key, not the allowlist. The two now
agree by construction.

### If a future setting is still written wrong

The boundary only knows the keys the binary names. A setting absent from both
lists flattens all the way, so an object-valued one added outside the registry
would regress silently — the same failure this fixed, in a key nobody measured.
`module-kiro-devenv-object-valued-setting-stays-nested` and its HM twin pin the
behavior; `module-kiro-scalar-setting-still-flattens` is the control that the
walk does not stop EARLY, which would write nested `{"chat":{...}}` that kiro
cannot read either.
