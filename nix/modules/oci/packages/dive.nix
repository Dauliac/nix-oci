# OCI packages - dive
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.dive = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for dive.";
        default = pkgs.dive;
        defaultText = lib.literalExpression "pkgs.dive";
        example = defaultText;
      };
    }
  );
}
