{
  lib,
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
      { pkgs, ... }:
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
                  type = types.listOf types.package;
                  description = "";
                  default = with pkgs; [
                    coreutils
                    bash
                    curl
                  ];
                  defaultText = lib.literalExpression ''
                    with pkgs; [
                      coreutils
                      bash
                      curl
                    ]
                  '';
                };
                entrypoint = mkOption {
                  description = "Debug entrypoint wrapper configuration.";
                  default = { };
                  type = types.submodule {
                    options = {
                      enabled = mkOption {
                        type = types.bool;
                        description = "Whether to enable debug entrypoint wrapper.";
                        default = false;
                      };
                      wrapper = mkOption {
                        type = types.package;
                        description = "Default behavior run sleep infinity fallback if entrypoint fail.";
                        default = pkgs.writeScriptBin "entrypoint" ./debug-entrypoint.sh;
                        defaultText = lib.literalExpression ''pkgs.writeScriptBin "entrypoint" ./debug-entrypoint.sh'';
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
