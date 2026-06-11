# OCI packages - skopeo-turbo (nix2container-turbo patched skopeo)
#
# Provides cross-machine layer caching, SOCI v2 index generation,
# and eStargz compression via patched skopeo.
{
  lib,
  flake-parts-lib,
  inputs,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { system, ... }:
    {
      options.oci.packages.skopeoTurbo = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        description = "The turbo-patched skopeo package from nix2container-turbo. Null when the input is not available.";
        default =
          if inputs ? nix2container-turbo then
            inputs.nix2container-turbo.packages.${system}.skopeo or null
          else
            null;
        defaultText = lib.literalExpression "inputs.nix2container-turbo.packages.\${system}.skopeo";
      };
    }
  );
}
