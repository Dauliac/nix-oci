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
                    default = "info";
                  };
                  ignore = mkOption {
                    type = types.listOf types.str;
                    description = "List of Dockle checkpoint IDs to ignore (e.g. `CIS-DI-0001`).";
                    default = [
                      # Docker Content Trust is irrelevant for nix2container
                      # images since they are built locally from the Nix store.
                      "CIS-DI-0005"
                      # HEALTHCHECK instruction check is irrelevant since
                      # there is no Dockerfile. Healthchecks are set via
                      # the image config by nix-oci service adapters.
                      "CIS-DI-0006"
                    ];
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
