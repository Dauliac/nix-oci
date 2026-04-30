# Container test.containerStructureTest.hermetic option
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
          options.test.containerStructureTest.hermetic = lib.mkOption {
            type = lib.types.bool;
            description = ''
              Run container-structure-test as a pure Nix derivation (check)
              instead of a flake app. Uses podman inside the Nix sandbox.
              Requires `extra-sandbox-paths = /sys` in nix.conf.
            '';
            default = cfg.oci.test.containerStructureTest.hermetic or false;
            defaultText = lib.literalExpression "cfg.oci.test.containerStructureTest.hermetic";
          };
        };
    };
}
