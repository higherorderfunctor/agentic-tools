{
  lib,
  harness,
  ...
}: let
  inherit (harness) evalHm;

  codexExtracted = builtins.fromJSON (builtins.readFile ../extracted.json);

  # Codex HM settings are embedded as one-line JSON in the reconciliation
  # activation script rather than exposed as a home.file source. Keeping this
  # extractor in the eval harness lets the semantic parity tests continue to
  # compare the exact desired value without weakening production ownership back
  # to an immutable store symlink.
  hmCodexSettings = evaluated: let
    script = evaluated.config.home.activation.codexSettingsReconcile.text;
    beforeClosingMarker = lib.head (lib.splitString "\nNAT_TOML_SETTINGS_EOF\n" script);
    settingsJson = lib.last (lib.splitString "\n" beforeClosingMarker);
  in
    builtins.fromJSON (builtins.unsafeDiscardStringContext settingsJson);

  codexSettingsActivation = config:
    (evalHm config).config.home.activation.codexSettingsReconcile.text;
in {
  inherit codexExtracted codexSettingsActivation hmCodexSettings;
}
