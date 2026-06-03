# OCI packages - syft
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.syft = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for syft.";
        default = pkgs.syft;
        defaultText = lib.literalExpression "pkgs.syft";
        example = defaultText;
      };
    }
  );
}
