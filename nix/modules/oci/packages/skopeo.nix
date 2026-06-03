# OCI packages - skopeo
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
      options.oci.packages.skopeo = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for skopeo.";
        default = inputs.nix2container.packages.${system}.skopeo-nix2container;
        defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.skopeo-nix2container";
        example = defaultText;
      };
    }
  );
}
