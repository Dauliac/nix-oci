# OCI packages - container-structure-test
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.containerStructureTest = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for container-structure-test.";
        default = pkgs.container-structure-test;
        defaultText = lib.literalExpression "pkgs.container-structure-test";
        example = defaultText;
      };
    }
  );
}
