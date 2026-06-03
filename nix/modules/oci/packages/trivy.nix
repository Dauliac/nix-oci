# OCI packages - trivy
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.trivy = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for trivy.";
        default = pkgs.trivy;
        defaultText = lib.literalExpression "pkgs.trivy";
        example = defaultText;
      };
    }
  );
}
