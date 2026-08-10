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
          default = config.oci.rootPath;
          defaultText = lib.literalExpression "config.oci.rootPath";
          description = "The root path for OCI manifest lock files (Nix path, used at build time). Each container gets a subdirectory.";
        };

        fromImageManifestDir = mkOption {
          type = types.str;
          default = "./oci";
          description = ''
            Runtime directory for manifest lock files, relative to the flake root.
            Used by `oci-update-manifests` to write lock files to the working copy.
            Each container gets a subdirectory: `<dir>/<containerId>/manifest-lock.json`.
          '';
        };
      };
    }
  );
}
