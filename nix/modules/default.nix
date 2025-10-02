{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    mkEnableOption
    ;
in
{
  imports = [
    ./lib
    ./per-system
    ./flake
    ./sbom.nix
    ./cve.nix
    ./credentials-leak.nix
    ./test.nix
  ];

  options = {
    oci = {
      enabled = mkEnableOption "Enable the OCI module.";
      # TODO: move it into devShell submodule ?
      devShellPackage = mkOption {
        type = types.package;
        description = "The package to use for the development shell.";
      };
      enableDevShell = mkOption {
        type = types.bool;
        description = "Whether to enable the flake development shell.";
        default = false;
      };
      rootPath = mkOption {
        type = types.path;
        defaultText = lib.literalExpression ''self + "/oci/"'';
        description = "The root path to store the Nix OCI resources.";
      };
      fromImageManifestRootPath = mkOption {
        type = types.path;
        defaultText = lib.literalExpression ''config.oci.rootPath + "/pulledManifestsLocks/"'';
        description = "The root path to store the pulled OCI image manifest JSON lockfiles.";
      };
      registry = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The OCI registry to use for pushing and pulling images.";
      };
    };
  };
}
