# OCI packages - grype
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.grype = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for grype.";
        default = pkgs.grype;
        defaultText = lib.literalExpression "pkgs.grype";
        example = defaultText;
      };
    }
  );
}
