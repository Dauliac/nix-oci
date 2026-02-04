# OCI packages - regctl
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.regctl = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for regctl (multi-arch manifest tool).";
        default = pkgs.regclient;
        defaultText = lib.literalExpression "pkgs.regclient";
        example = defaultText;
      };
    }
  );
}
