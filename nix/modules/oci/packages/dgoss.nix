# OCI packages - dgoss
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.dgoss = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for dgoss.";
        default = pkgs.dgoss;
        defaultText = lib.literalExpression "pkgs.dgoss";
        example = defaultText;
      };
    }
  );
}
