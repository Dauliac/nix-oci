{
  lib,
  flake-parts-lib,
  inputs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        system,
        pkgs,
        ...
      }:
      {
        options.oci.packages = mkOption {
          default = { };
          description = "";
          type = types.submodule {
            options = {
              skopeo = mkOption {
                type = types.package;
                description = "The package to use for skopeo.";
                default = inputs.nix2container.packages.${system}.skopeo-nix2container;
                defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.skopeo-nix2container";
              };
              #  TODO move all of these into packages under submodules
              containerStructureTest = mkOption {
                type = types.package;
                description = "The package to use for container-structure-test.";
                default = pkgs.container-structure-test;
                defaultText = lib.literalExpression "pkgs.container-structure-test";
              };
              podman = mkOption {
                type = types.package;
                description = "The package to use for podman.";
                default = pkgs.podman;
                defaultText = lib.literalExpression "pkgs.podman";
              };
              grype = mkOption {
                type = types.package;
                description = "The package to use for grype.";
                default = pkgs.grype;
                defaultText = lib.literalExpression "pkgs.grype";
              };
              syft = mkOption {
                type = types.package;
                description = "The package to use for syft.";
                default = pkgs.syft;
                defaultText = lib.literalExpression "pkgs.syft";
              };
              trivy = mkOption {
                type = types.package;
                description = "The package to use for trivy.";
                default = pkgs.trivy;
                defaultText = lib.literalExpression "pkgs.trivy";
              };
              dive = mkOption {
                type = types.package;
                description = "The package to use for dive.";
                default = pkgs.dive;
                defaultText = lib.literalExpression "pkgs.dive";
              };
              nix2container = mkOption {
                type = types.attrs;
                description = "The nix2container package.";
                default = inputs.nix2container.packages.${system}.nix2container;
                defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.nix2container";
              };
              dgoss = mkOption {
                type = types.package;
                description = "The package to use for dgoss.";
                default = pkgs.dgoss;
                defaultText = lib.literalExpression "pkgs.dgoss";
              };
              skaffold = mkOption {
                type = types.package;
                description = "The package to use for skaffold.";
                default = pkgs.skaffold;
                defaultText = lib.literalExpression "pkgs.skaffold";
              };
            };
          };
        };
      }
    );
  };
}
