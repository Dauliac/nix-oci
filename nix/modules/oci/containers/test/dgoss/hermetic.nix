# Container test.dgoss.hermetic option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.test.dgoss.hermetic = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Run dgoss as a pure Nix derivation (check) instead of a flake
              app. Uses podman inside the Nix sandbox.
              Requires `extra-sandbox-paths = /sys` in nix.conf.
            '';
            default = cfg.oci.test.dgoss.hermetic or false;
            defaultText = lib.literalExpression "cfg.oci.test.dgoss.hermetic";
          };
        };
    };
}
