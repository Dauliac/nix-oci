# OCI packages - vulnix
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.vulnix = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for vulnix.";
        default = pkgs.vulnix;
        defaultText = lib.literalExpression "pkgs.vulnix";
        example = defaultText;
      };
    }
  );
}
