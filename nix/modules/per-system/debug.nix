localflake:
{
  config,
  lib,
  inputs,
  self,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        system,
        ...
      }:
      {
        options.oci = {
          debug = mkOption {
            description = "Add debug build in output.";
            default = { };
            type = types.submodule {
              options = {
                enabled = mkOption {
                  type = types.bool;
                  description = "";
                  default = false;
                };
                packages = mkOption {
                  type = types.listOf types.packages;
                  description = "";
                  default = with pkgs; [
                    coreutils
                    bash
                    curl
                  ];
                };
                entrypoint = mkOption {
                  type = types.submodule {
                    options = {
                      enabled = mkOption {
                        type = types.bool;
                        description = "";
                        default = false;
                      };
                      wrapper = mkOption {
                        type = types.package;
                        description = "Default behavior run sleep infinity fallback if entrypoint fail.";
                        default = pkgs.writeScriptBin "entrypoint" ./debug-entrypoint.sh;
                      };
                    };
                  };
                };
              };
            };
          };
        };
      }
    );
  };
}
