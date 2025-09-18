localflake:
{
  config,
  lib,
  inputs,
  self,
  flake-parts-lib,
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
        config,
        pkgs,
        system,
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
                default = localflake.inputs.nix2container.packages.${system}.skopeo-nix2container;
              };
              #  TODO move all of these into packages under submodules
              containerStructureTest = mkOption {
                type = types.package;
                description = "The package to use for container-structure-test.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.container-structure-test;
              };
              podman = mkOption {
                type = types.package;
                description = "The package to use for podman.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.podman;
              };
              grype = mkOption {
                type = types.package;
                description = "The package to use for grype.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.grype;
              };
              syft = mkOption {
                type = types.package;
                description = "The package to use for syft.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.syft;
              };
              trivy = mkOption {
                type = types.package;
                description = "The package to use for trivy.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.trivy;
              };
              dive = mkOption {
                type = types.package;
                description = "The package to use for dive.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.dive;
              };
              nix2container = mkOption {
                type = types.attrs;
                description = "The nix2container package.";
                default = localflake.inputs.nix2container.packages.${system}.nix2container;
              };
              dgoss = mkOption {
                type = types.package;
                description = "The package to use for dgoss.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.dgoss;
              };
              skaffold = mkOption {
                type = types.package;
                description = "The package to use for skaffold.";
                default = localflake.inputs.nixpkgs.legacyPackages.${system}.skaffold;
              };
            };
          };
        };
      }
    );
  };
}
