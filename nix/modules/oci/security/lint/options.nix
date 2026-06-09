{
  config,
  lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    mkEnableOption
    types
    ;
in
{
  options = {
    oci = {
      lint = mkOption {
        default = { };
        description = "Configuration for container image linting.";
        type = types.submodule {
          options = {
            dockle = mkOption {
              description = "Configuration for container image linting using Dockle (CIS Benchmarks & best practices).";
              default = { };
              type = types.submodule {
                options = {
                  enabled = mkEnableOption "container image linting with Dockle";
                  exitLevel = mkOption {
                    type = types.enum [
                      "info"
                      "warn"
                      "fatal"
                    ];
                    description = "Minimum severity level that causes a non-zero exit code.";
                    default = "warn";
                  };
                  ignore = mkOption {
                    type = types.listOf types.str;
                    description = "List of Dockle checkpoint IDs to ignore (e.g. `CIS-DI-0001`).";
                    default = [ ];
                    example = [
                      "CIS-DI-0001"
                      "DKL-DI-0006"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
