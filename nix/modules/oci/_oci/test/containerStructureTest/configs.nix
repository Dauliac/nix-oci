{ lib, ... }:
{
  options.test.containerStructureTest.configs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    description = "User-provided container-structure-test config YAML files. See https://github.com/GoogleContainerTools/container-structure-test for the schema.";
    default = [ ];
  };
}
