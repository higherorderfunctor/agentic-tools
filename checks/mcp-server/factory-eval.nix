# Factory contracts for this owner or shared primitive.
{
  lib,
  pkgs,
  harness,
  ...
}: let
  inherit (import ../../lib/testing/factory-harness.nix {inherit lib pkgs harness;}) ai evalService mkServiceServerDef mkTest;
in {
  checks = {
    # ── mcpServer.commonSchema tests ────────────────────────────────
    factory-mcpServer-commonSchema-minimal = mkTest "mcpServer-commonSchema-minimal" (
      let
        evaluated = lib.evalModules {
          modules = [
            ai.mcpServer.commonSchema
            {
              config = {
                type = "stdio";
                package = pkgs.hello;
                command = "hello";
                args = ["--version"];
              };
            }
          ];
        };
      in
        evaluated.config.type
        == "stdio"
        && evaluated.config.command == "hello"
    );

    factory-mcpServer-commonSchema-type-enforced = mkTest "mcpServer-commonSchema-type-enforced" (
      # `type` is nullable in the new schema (renderServer infers from
      # which other fields are set), but the enum constraint still
      # applies when a value is provided. Setting an invalid type must
      # fail evaluation.
      let
        result =
          builtins.tryEval
          (lib.evalModules {
            modules = [
              ai.mcpServer.commonSchema
              {config.type = "BOGUS_TRANSPORT";}
            ];
          }).config.type;
      in
        !result.success
    );

    # Bridge mode honors service.host in the shared mcp-proxy wrapper, so it
    # needs no per-server metadata declaration and still accepts overrides.
    factory-mcpServer-service-host-bridge-accepted = mkTest "mcpServer-service-host-bridge-accepted" (
      let
        result = evalService {
          config.service.host = "127.0.0.2";
          serverDef = mkServiceServerDef "bridge" {};
        };
      in
        result.config.server.service.host == "127.0.0.2"
    );

    # A native mode must state its audit result. This is the structural guard
    # that turns a future bridge -> native switch into an evaluation failure.
    factory-mcpServer-service-host-native-audit-required = mkTest "mcpServer-service-host-native-audit-required" (
      let
        attempt = builtins.tryEval (builtins.deepSeq
          (evalService {
            serverDef = mkServiceServerDef "test-mcp --http" {};
          }).config.server.service.host
          true);
      in
        !attempt.success
    );

    factory-mcpServer-service-host-native-supported = mkTest "mcpServer-service-host-native-supported" (
      let
        result = evalService {
          config.service.host = "127.0.0.2";
          serverDef = mkServiceServerDef "test-mcp --http" {honorsServiceHost = true;};
        };
      in
        result.config.server.service.host == "127.0.0.2"
    );

    # Any concrete value is rejected for an unsupported native mode, including
    # the old apparent default. Leaving it unset is the only accepted shape.
    factory-mcpServer-service-host-native-unsupported-rejected = mkTest "mcpServer-service-host-native-unsupported-rejected" (
      let
        attempt = builtins.tryEval (builtins.deepSeq
          (evalService {
            config.service.host = "127.0.0.1";
            serverDef = mkServiceServerDef "test-mcp --http" {honorsServiceHost = false;};
          }).config.server.service.host
          true);
      in
        !attempt.success
    );

    # ── mcpServer.mkMcpServer tests ─────────────────────────────────
    factory-mcpServer-mkMcpServer-returns-function = mkTest "mkMcpServer-returns-function" (
      let
        factory = ai.mcpServer.mkMcpServer {
          name = "test";
          defaults = {package = pkgs.hello;};
        };
      in
        builtins.isFunction factory
    );

    factory-mcpServer-mkMcpServer-builds-instance = mkTest "mkMcpServer-builds-instance" (
      let
        factory = ai.mcpServer.mkMcpServer {
          name = "test";
          defaults = {
            package = pkgs.hello;
            type = "stdio";
            command = "hello";
          };
        };
        instance = factory {args = ["--version"];};
      in
        instance.type
        == "stdio"
        && instance.command == "hello"
        && instance.args == ["--version"]
    );

    factory-mcpServer-mkMcpServer-custom-options = mkTest "mkMcpServer-custom-options" (
      let
        factory = ai.mcpServer.mkMcpServer {
          name = "weird";
          defaults = {
            package = pkgs.hello;
            type = "stdio";
            command = "hello";
          };
          options = {
            turboMode = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        };
        instance = factory {turboMode = true;};
      in
        instance.turboMode or false
    );

    factory-mcpServer-mkMcpServer-list-merge = mkTest "mkMcpServer-list-merge" (
      let
        factory = ai.mcpServer.mkMcpServer {
          name = "test";
          defaults = {
            package = pkgs.hello;
            type = "stdio";
            command = "hello";
            args = ["--from-defaults"];
          };
        };
        instance = factory {args = ["--from-consumer"];};
      in
        # With module-system merge on listOf: ["--from-defaults" "--from-consumer"]
        # Both values must be present (concatenation semantics).
        builtins.elem "--from-defaults" instance.args
        && builtins.elem "--from-consumer" instance.args
    );
  };
}
