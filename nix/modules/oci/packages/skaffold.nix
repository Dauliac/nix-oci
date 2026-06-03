# OCI packages - skaffold
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.skaffold = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for skaffold.";
        default = pkgs.skaffold;
        defaultText = lib.literalExpression "pkgs.skaffold";
        example = defaultText;
      };
    }
  );
}
