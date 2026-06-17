# Per-system OCI path infrastructure options.
#
# These are shared paths that per-container modules reference
# to compute container-specific defaults (via perContainer).
{
  lib,
  self,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci = {
        rootPath = mkOption {
          type = types.path;
          default = self + "/oci/";
          defaultText = lib.literalExpression ''self + "/oci/"'';
          description = "The root path to store the Nix OCI resources.";
        };

        fromImageManifestRootPath = mkOption {
          type = types.path;
          default = config.oci.rootPath + "/pulledManifestsLocks/";
          defaultText = lib.literalExpression ''config.oci.rootPath + "/pulledManifestsLocks/"'';
          description = "The root path to store the pulled OCI image manifest JSON lockfiles.";
        };
      };
    }
  );
}
