# Deployment smoke through the public module. The small grammar accommodates
# existing writer guards and @repo routing; it is not a semantic fixture design.
{
  lib,
  pkgs,
  self,
}: let
  grammar = self.lib.ai.strictdocGrammar {inherit lib;};
  smokeElement = tag: properties:
    with grammar.dsl;
      el tag properties {
        fields = [
          (field.required (field.str "UID"))
          (field.str "TITLE")
          (field.str "STATEMENT")
          (field.required (field.one "AUTHORED_BY" ["llm" "human"]))
          (field.str "PARENT_FP")
        ];
        relations = null;
      };
  evaluated = lib.evalModules {
    specialArgs = {
      inherit pkgs;
      lib = lib // self.lib;
    };
    modules = [
      self.devenvModules.nix-agentic-tools
      ({lib, ...}: {
        # Only the shell sinks consumed below are evaluated. The complete
        # declaration tree is separately checked by options-doc-ai-parity.
        config._module.check = false;
        options = {
          packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            default = [];
          };
          processes = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
          };
          tasks = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = {};
          };
        };
        config.ai.strictdoc = {
          enable = true;
          grammars.smoke = {
            target = "grammar.sgra";
            elements = [
              (smokeElement "EMPTY" {prefix = "";})
              (smokeElement "ITEM" {prefix = "ITEM-";})
              (smokeElement "UNPREFIXED" {})
            ];
          };
        };
      })
    ];
  };
  cfg = evaluated.config;
  project =
    (evaluated.extendModules {
      modules = [{ai.strictdoc.scribeSource = "project";}];
    }).config;
  projectProgram = name: lib.getExe (lib.findFirst (p: (p.meta.mainProgram or "") == name) null project.packages);
  generate = pkgs.writeShellScript "generate-smoke-grammar" cfg.tasks."generate:sgra".exec;
  daemon = pkgs.writeShellScript "start-smoke-daemon" ''
    set -euETo pipefail
    shopt -s inherit_errexit 2>/dev/null || :
    exec ${cfg.processes.scribe.exec}
  '';
in
  pkgs.runCommand "strictdoc-runtime-installation" {
    nativeBuildInputs = cfg.packages ++ [pkgs.python3];
    passthru = {
      inherit daemon generate;
      inherit (cfg) packages;
    };
  } ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${lib.getExe pkgs.python3} ${./strictdoc-runtime-installation.py} ${generate} ${daemon} ${projectProgram "scribe"} ${projectProgram "sdoc-board"}
    touch "$out"
  ''
