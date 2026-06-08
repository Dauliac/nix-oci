# Per-container: image option
{ lib, ... }:
{
  options.image = lib.mkOption {
    type = lib.types.package;
    description = ''
      The nix2container `buildImage` output derivation.
      Must have `imageName` and `imageTag` passthru attributes
      (standard for nix2container images).
    '';
  };
}
