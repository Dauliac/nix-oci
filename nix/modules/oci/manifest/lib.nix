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
              # Each container gets its own subdirectory: <rootPath>/<containerId>/
              containerDir = perSystemConfig.fromImageManifestRootPath + "/${containerId}";
              manifestLockPath = containerDir + "/manifest-lock.json";
              fromImage' = (builtins.removeAttrs oci.fromImage [ "enabled" ]) // {
                imageManifest = manifestLockPath;
              };
            in
            perSystemConfig.packages.nix2container.pullImageFromManifest fromImage';
        };

        mkOCIPulledManifestLockUpdateScript = {
          type = types.functionTo types.package;
          description = ''
            Build a go-task wrapper that pulls all fromImage manifests in parallel.
            Each container gets its own task; go-task runs them concurrently
            with prefixed output.
          '';
          file = "nix/modules/oci/manifest/lib.nix";
          fn =
            {
              self,
              perSystemConfig,
              ...
            }:
            let
              # Generate one pull script per container
              # Files go to $MANIFEST_DIR/<containerId>/{manifest-lock.json,base-passwd,base-group}
              mkPullScript =
                containerId:
                let
                  oci = perSystemConfig.containers.${containerId};
                  inherit (oci) fromImage;
                  manifest = ociLib.mkOCIPulledManifestLock {
                    inherit perSystemConfig containerId;
                  };
                in
                pkgs.writeShellApplication {
                  name = "pull-manifest-${containerId}";
                  runtimeInputs = [
                    pkgs.skopeo
                    pkgs.jq
                  ];
                  excludeShellChecks = [ "SC2034" ];
                  text = ''
                    : "''${MANIFEST_DIR:=./oci}"
                    dir="$MANIFEST_DIR/${containerId}"
                    mkdir -p "$dir"
                    mf="$dir/manifest-lock.json"
                    pw="$dir/base-passwd"
                    gr="$dir/base-group"

                    manifest=$(${manifest.getManifest}/bin/get-manifest)
                    if [ -f "$mf" ]; then
                      currentContent=$(cat "$mf")
                      if [ "$currentContent" != "$manifest" ]; then
                        echo "Updating ${fromImage.imageName}:${fromImage.imageTag}"
                        echo "$manifest" > "$mf"
                      else
                        echo "Up to date: ${fromImage.imageName}:${fromImage.imageTag}"
                      fi
                    else
                      echo "Generating ${fromImage.imageName}:${fromImage.imageTag}"
                      echo "$manifest" > "$mf"
                    fi

                    # Extract /etc/passwd and /etc/group from the base image layers.
                    echo "Extracting identity files for ${fromImage.imageName}:${fromImage.imageTag}"
                    tmpdir="$(mktemp -d)"
                    trap 'rm -rf "$tmpdir"' EXIT

                    skopeo copy --override-os linux \
                      "docker://${fromImage.imageName}:${fromImage.imageTag}" \
                      "oci:$tmpdir/image:${fromImage.imageTag}" >/dev/null

                    mkdir -p "$tmpdir/extract/etc"
                    for digest in $(jq -r '.layers[].digest' "$mf"); do
                      hash="''${digest#sha256:}"
                      blob="$tmpdir/image/blobs/sha256/$hash"
                      if [ -f "$blob" ]; then
                        tar -xzf "$blob" -C "$tmpdir/extract" --no-same-owner \
                          etc/passwd etc/group ./etc/passwd ./etc/group 2>/dev/null \
                        || tar -xf "$blob" -C "$tmpdir/extract" --no-same-owner \
                          etc/passwd etc/group ./etc/passwd ./etc/group 2>/dev/null \
                        || true
                      fi
                    done

                    if [ -f "$tmpdir/extract/etc/passwd" ]; then
                      cp "$tmpdir/extract/etc/passwd" "$pw"
                    else
                      touch "$pw"
                    fi
                    if [ -f "$tmpdir/extract/etc/group" ]; then
                      cp "$tmpdir/extract/etc/group" "$gr"
                    else
                      touch "$gr"
                    fi
                  '';
                };

              # Iterate over fromImage-enabled containers directly.
              # Do NOT use perSystemConfig.internal.pulledOCIs — that evaluates
              # mkOCIPulledManifestLock which requires the lock file to exist.
              fromImageContainers = lib.filterAttrs (_: c: c.fromImage.enabled) perSystemConfig.containers;

              pullScripts = lib.mapAttrs (containerId: _: mkPullScript containerId) fromImageContainers;

              # Generate Taskfile JSON with one task per container
              taskfile = {
                version = "3";
                output = "prefixed";
                run = "once";
                set = [
                  "errexit"
                  "nounset"
                  "pipefail"
                ];
                tasks =
                  (lib.mapAttrs (containerId: script: {
                    desc = "Pull manifest for ${containerId}";
                    label = "pull:${containerId}";
                    cmds = [ (lib.getExe script) ];
                  }) pullScripts)
                  // {
                    default = {
                      desc = "Pull all fromImage manifests in parallel";
                      deps = lib.attrNames pullScripts;
                    };
                  };
              };

              taskfileJson = pkgs.writeText "oci-update-manifests-taskfile.json" (builtins.toJSON taskfile);
            in
            pkgs.writeShellApplication {
              name = "oci-update-manifests";
              runtimeInputs = [ pkgs.go-task ];
              text = ''
                export MANIFEST_DIR="''${MANIFEST_DIR:-${perSystemConfig.fromImageManifestDir}}"
                mkdir -p "$MANIFEST_DIR"
                exec task --taskfile="${taskfileJson}" --dir="$PWD" "$@"
              '';
            };
        };
      };
    };
}
