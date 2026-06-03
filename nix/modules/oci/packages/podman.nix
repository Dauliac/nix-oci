# OCI packages - podman
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { pkgs, ... }:
    {
      options.oci.packages.podman = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for podman.";
        default = pkgs.podman;
        defaultText = lib.literalExpression "pkgs.podman";
        example = defaultText;
      };
    }
  );
}
