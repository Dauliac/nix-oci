# Manifest lock functions
# These handle OCI image manifest fetching and locking
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
      flakeLib = cfg.lib.flake.oci or { };
    in
    {
      nix-lib.lib.oci = {
        mkOCIPulledManifestLock = {
          type = types.functionTo types.package;
          description = "Build OCI manifest to pull from registry";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.containers.${containerId};
              manifestLockPath = flakeLib.mkOCIPulledManifestLockPath {
                inherit (globalConfig) fromImageManifestRootPath;
                inherit (oci) fromImage;
              };
              fromImage' = (builtins.removeAttrs oci.fromImage [ "enabled" ]) // {
                imageManifest = manifestLockPath;
              };
            in
            perSystemConfig.packages.nix2container.pullImageFromManifest fromImage';
        };

        mkOCIPulledManifestLockUpdateScript = {
          type = types.functionTo types.package;
          description = "Build script to update pulled OCI manifest locks";
          fn =
            {
              self,
              perSystemConfig,
              globalConfig,
            }:
            let
              manifestRootPath = flakeLib.mkOCIPulledManifestLockRelativeRootPath {
                inherit (globalConfig) fromImageManifestRootPath;
                inherit self;
              };
              update = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  containerId: container:
                  let
                    oci = perSystemConfig.containers.${containerId};
                    inherit (oci) fromImage;
                    manifestPath = flakeLib.mkOCIPulledManifestLockRelativePath {
                      inherit self;
                      manifestLockPath = flakeLib.mkOCIPulledManifestLockPath {
                        inherit (globalConfig) fromImageManifestRootPath;
                        inherit fromImage;
                      };
                    };
                    manifest = ociLib.mkOCIPulledManifestLock {
                      inherit perSystemConfig containerId globalConfig;
                    };
                  in
                  ''
                    declare -g manifest
                    manifest=$(${manifest.getManifest}/bin/get-manifest)
                    if [ -f "${manifestPath}" ]; then
                      currentContent=$(cat "${manifestPath}")
                      newContent=$(echo "$manifest")
                      if [ "$currentContent" != "$newContent" ]; then
                        printf "Updating lock manifest for ${containerId}::${fromImage.imageName}:${fromImage.imageTag} in ${manifestPath} ...\n"
                        echo "$manifest" > "${manifestPath}"
                      fi
                    else
                      printf "Generating lock manifest for ${containerId}::${fromImage.imageName}:${fromImage.imageTag} in ${manifestPath} ...\n"
                      echo "$manifest" > "${manifestPath}"
                    fi
                  ''
                ) perSystemConfig.internal.pulledOCIs
              );
            in
            pkgs.writeShellScriptBin "update-pulled-oci-manifests-locks" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              mkdir -p "${manifestRootPath}"
              ${update}
            '';
        };
      };
    };
}
