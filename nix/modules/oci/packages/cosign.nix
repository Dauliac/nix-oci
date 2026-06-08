# OCI packages - cosign
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.cosign = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for cosign.";
        default = pkgs.cosign;
        defaultText = lib.literalExpression "pkgs.cosign";
        example = defaultText;
      };
    }
  );
}
