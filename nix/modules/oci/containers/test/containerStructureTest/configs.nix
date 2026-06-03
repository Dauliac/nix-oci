# Container test.containerStructureTest.configs option
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
        { name, ... }:
        {
          options.test.containerStructureTest.configs = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            description = "List of container-structure-test configuration files to run.";
            default = [
              (cfg.oci.rootPath + name + "/test/container-structure-test.yaml")
            ];
            defaultText = lib.literalExpression ''[ (cfg.oci.rootPath + name + "/test/container-structure-test.yaml") ]'';
          };
        };
    };
}
