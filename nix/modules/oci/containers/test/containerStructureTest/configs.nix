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
        { containerName, ... }:
        {
          options.test.containerStructureTest.configs = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            description = "List of container-structure-test configuration files to run.";
            default = [
              (cfg.oci.rootPath + containerName + "/test/container-structure-test.yaml")
            ];
            defaultText = lib.literalExpression ''[ (cfg.oci.rootPath + containerName + "/test/container-structure-test.yaml") ]'';
          };
        };
    };
}
