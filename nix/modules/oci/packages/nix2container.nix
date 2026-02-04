# OCI packages - nix2container
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
      options.oci.packages.nix2container = lib.mkOption rec {
        type = lib.types.attrs;
        description = "The nix2container package.";
        default = inputs.nix2container.packages.${system}.nix2container;
        defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.nix2container";
        example = defaultText;
      };
    }
  );
}
