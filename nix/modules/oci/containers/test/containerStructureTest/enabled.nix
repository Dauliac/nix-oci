# Container test.containerStructureTest.enabled option
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
          options.test.containerStructureTest.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable container-structure-test for validating container structure and metadata.";
            default = cfg.oci.test.containerStructureTest.enabled;
            defaultText = lib.literalExpression "cfg.oci.test.containerStructureTest.enabled";
          };
        };
    };
}
