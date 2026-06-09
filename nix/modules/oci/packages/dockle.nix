# OCI packages - dockle
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.dockle = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for dockle.";
        default = pkgs.dockle;
        defaultText = lib.literalExpression "pkgs.dockle";
        example = defaultText;
      };
    }
  );
}
