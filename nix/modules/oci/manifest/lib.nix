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
          file = "nix/modules/oci/manifest/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              ...
            }:
            let
              oci = perSystemConfig.containers.${containerId};
              manifestLockPath = flakeLib.mkOCIPulledManifestLockPath {
                inherit (perSystemConfig) fromImageManifestRootPath;
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
          file = "nix/modules/oci/manifest/lib.nix";
          fn =
            {
              self,
              perSystemConfig,
              ...
            }:
            let
              manifestRootPath = flakeLib.mkOCIPulledManifestLockRelativeRootPath {
                inherit (perSystemConfig) fromImageManifestRootPath;
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
                        inherit (perSystemConfig) fromImageManifestRootPath;
                        inherit fromImage;
                      };
                    };
                    passwdPath = flakeLib.mkOCIPulledManifestLockRelativePath {
                      inherit self;
                      manifestLockPath = flakeLib.mkOCIPulledBasePasswdPath {
                        inherit (perSystemConfig) fromImageManifestRootPath;
                        inherit fromImage;
                      };
                    };
                    groupPath = flakeLib.mkOCIPulledManifestLockRelativePath {
                      inherit self;
                      manifestLockPath = flakeLib.mkOCIPulledBaseGroupPath {
                        inherit (perSystemConfig) fromImageManifestRootPath;
                        inherit fromImage;
                      };
                    };
                    manifest = ociLib.mkOCIPulledManifestLock {
                      inherit perSystemConfig containerId;
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

                    # Extract /etc/passwd and /etc/group from the base image layers.
                    # These are used at eval time to merge base image users into the
                    # NixOS-generated /etc/passwd (no IFD required).
                    # Wrapped in a subshell so trap and temporary variables are scoped
                    # per container and do not leak across iterations.
                    (
                      printf "Extracting base image identity files for ${containerId}::${fromImage.imageName}:${fromImage.imageTag} ...\n"
                      _nix_oci_tmpdir="$(mktemp -d)"
                      trap 'rm -rf "$_nix_oci_tmpdir"' EXIT

                      ${pkgs.skopeo}/bin/skopeo copy --override-os linux \
                        "docker://${fromImage.imageName}:${fromImage.imageTag}" \
                        "oci:$_nix_oci_tmpdir/image:${fromImage.imageTag}" >/dev/null

                      mkdir -p "$_nix_oci_tmpdir/extract/etc"
                      for _digest in $(${pkgs.jq}/bin/jq -r '.layers[].digest' "${manifestPath}"); do
                        _hash="''${_digest#sha256:}"
                        _blob="$_nix_oci_tmpdir/image/blobs/sha256/$_hash"
                        if [ -f "$_blob" ]; then
                          tar -xzf "$_blob" -C "$_nix_oci_tmpdir/extract" --no-same-owner \
                            etc/passwd etc/group ./etc/passwd ./etc/group 2>/dev/null \
                          || tar -xf "$_blob" -C "$_nix_oci_tmpdir/extract" --no-same-owner \
                            etc/passwd etc/group ./etc/passwd ./etc/group 2>/dev/null \
                          || true
                        fi
                      done

                      if [ -f "$_nix_oci_tmpdir/extract/etc/passwd" ]; then
                        cp "$_nix_oci_tmpdir/extract/etc/passwd" "${passwdPath}"
                      else
                        touch "${passwdPath}"
                      fi
                      if [ -f "$_nix_oci_tmpdir/extract/etc/group" ]; then
                        cp "$_nix_oci_tmpdir/extract/etc/group" "${groupPath}"
                      else
                        touch "${groupPath}"
                      fi
                    )
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
