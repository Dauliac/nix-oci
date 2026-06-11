# OCI packages - conftest
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.conftest = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for conftest.";
        default = pkgs.conftest;
        defaultText = lib.literalExpression "pkgs.conftest";
        example = defaultText;
      };
    }
  );
}
