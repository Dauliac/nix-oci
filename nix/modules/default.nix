localflake:
{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    mkEnableOption
    mdDoc
    ;
in
{
  imports = [
    (import ./flake localflake)
    (import ./per-system localflake)
    (import ./sbom.nix localflake)
    (import ./cve.nix localflake)
    (import ./credentials-leak.nix localflake)
    (import ./test.nix localflake)
  ];
  options = {
    oci = {
      enabled = mkEnableOption "Enable the OCI module.";
      # TODO: move it into devShell submodule ?
      devShellPackage = mkOption {
        type = types.package;
        description = mdDoc "The package to use for the development shell.";
      };
      enableDevShell = mkOption {
        type = types.bool;
        description = mdDoc "Whether to enable the flake development shell.";
        default = false;
      };
      rootPath = mkOption {
        type = types.path;
        default = self + "/oci/";
        defaultText = lib.literalExpression ''self + "/oci/"'';
        description = mdDoc "The root path to store the Nix OCI resources.";
      };
      fromImageManifestRootPath = mkOption {
        type = types.path;
        default = cfg.oci.rootPath + "/pulledManifestsLocks/";
        defaultText = lib.literalExpression ''cfg.oci.rootPath + "/pulledManifestsLocks/"'';
        description = mdDoc "The root path to store the pulled OCI image manifest JSON lockfiles.";
      };
      registry = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc "The OCI registry to use for pushing and pulling images.";
      };
    };
  };
}
