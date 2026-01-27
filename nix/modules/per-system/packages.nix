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
              skopeo = mkOption rec {
                type = types.package;
                description = "The package to use for skopeo.";
                default = inputs.nix2container.packages.${system}.skopeo-nix2container;
                defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.skopeo-nix2container";
                example = defaultText;
              };
              #  TODO: move all of these into packages under submodules
              containerStructureTest = mkOption rec {
                type = types.package;
                description = "The package to use for container-structure-test.";
                default = pkgs.container-structure-test;
                defaultText = lib.literalExpression "pkgs.container-structure-test";
                example = defaultText;
              };
              podman = mkOption rec {
                type = types.package;
                description = "The package to use for podman.";
                default = pkgs.podman;
                defaultText = lib.literalExpression "pkgs.podman";
                example = defaultText;
              };
              grype = mkOption rec {
                type = types.package;
                description = "The package to use for grype.";
                default = pkgs.grype;
                defaultText = lib.literalExpression "pkgs.grype";
                example = defaultText;
              };
              syft = mkOption rec {
                type = types.package;
                description = "The package to use for syft.";
                default = pkgs.syft;
                defaultText = lib.literalExpression "pkgs.syft";
                example = defaultText;
              };
              trivy = mkOption rec {
                type = types.package;
                description = "The package to use for trivy.";
                default = pkgs.trivy;
                defaultText = lib.literalExpression "pkgs.trivy";
                example = defaultText;
              };
              dive = mkOption rec {
                type = types.package;
                description = "The package to use for dive.";
                default = pkgs.dive;
                defaultText = lib.literalExpression "pkgs.dive";
                example = defaultText;
              };
              nix2container = mkOption rec {
                type = types.attrs;
                description = "The nix2container package.";
                default = inputs.nix2container.packages.${system}.nix2container;
                defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.nix2container";
                example = defaultText;
              };
              dgoss = mkOption rec {
                type = types.package;
                description = "The package to use for dgoss.";
                default = pkgs.dgoss;
                defaultText = lib.literalExpression "pkgs.dgoss";
                example = defaultText;
              };
              skaffold = mkOption rec {
                type = types.package;
                description = "The package to use for skaffold.";
                default = pkgs.skaffold;
                defaultText = lib.literalExpression "pkgs.skaffold";
                example = defaultText;
              };
              regctl = mkOption rec {
                type = types.package;
                description = "The package to use for regctl (multi-arch manifest tool).";
                default = pkgs.regclient;
                defaultText = lib.literalExpression "pkgs.regclient";
                example = defaultText;
              };
            };
          };
        };
      }
    );
  };
}
