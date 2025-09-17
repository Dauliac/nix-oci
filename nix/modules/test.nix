localflake:
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    mdDoc
    ;
in
{
  options = {
    oci = {
      test = mkOption {
        default = { };
        description = mdDoc "Global configuration for container testing tools.";
        type = types.submodule {
          options = {
            dive = mkOption {
              default = { };
              description = mdDoc "Configuration for Dive container image analysis tool.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = mdDoc "Whether to enable Dive analysis globally for all containers.";
                    default = false;
                  };
                };
              };
            };
            containerStructureTest = mkOption {
              default = { };
              description = mdDoc "Configuration for container-structure-test validation tool.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = mdDoc "Whether to enable container-structure-test globally for all containers.";
                    default = false;
                  };
                };
              };
            };
            dgoss = mkOption {
              default = { };
              description = mdDoc "Configuration for dgoss (Docker + goss) testing framework.";
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.bool;
                    description = mdDoc "Whether to enable dgoss testing globally for all containers.";
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
