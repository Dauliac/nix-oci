{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    oci = {
      test = mkOption {
        default = { };
        description = "Global configuration for container testing tools.";
        type = types.submodule {
          options = {
            dive = mkOption {
              default = { };
              description = "Configuration for Dive container image analysis tool.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = "Whether to enable Dive analysis globally for all containers.";
                    default = false;
                  };
                };
              };
            };
            containerStructureTest = mkOption {
              default = { };
              description = "Configuration for container-structure-test validation tool.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = "Whether to enable container-structure-test globally for all containers.";
                    default = false;
                  };
                };
              };
            };
            dgoss = mkOption {
              default = { };
              description = "Configuration for dgoss (Docker + goss) testing framework.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = "Whether to enable dgoss testing globally for all containers.";
                    default = false;
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
