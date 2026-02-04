# Podman-related OCI functions
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
        mkPodmanOCI = {
          type = types.functionTo types.package;
          description = "Build a container image with Podman and a non-root daemon";
          fn =
            {
              perSystemConfig,
              package,
              dependencies ? [ ],
            }:
            let
              podmanConfig = pkgs.writeTextDir "etc/containers/containers.conf" ''
                [containers]
                log_level = "error"
                rootless = true
              '';
              entrypointScript = ./podman-oci-entrypoint.sh;
              tag = flakeLib.mkOCITag {
                inherit package;
                fromImage = {
                  enabled = false;
                };
              };
              user = "podman";
            in
            perSystemConfig.packages.nix2container.buildImage {
              name = "podman";
              inherit tag;
              copyToRoot = [
                (ociLib.mkRoot {
                  inherit tag user package;
                  dependencies = [
                    pkgs.podman
                    podmanConfig
                  ]
                  ++ dependencies;
                })
                entrypointScript
              ];
              config = {
                User = user;
                Env = [ "USER=${user}" ];
                entrypoint = [
                  "/podman-oci-entrypoint.sh"
                  "$@"
                ];
              };
            };
        };

        mkPodmanOCIRunScript = {
          type = types.functionTo types.package;
          description = "Build a script to run commands in a Podman container";
          fn =
            {
              perSystemConfig,
              package,
              dependencies ? [ ],
            }:
            let
              podman = ociLib.mkPodmanOCI {
                inherit perSystemConfig package dependencies;
              };
            in
            pkgs.writeShellScriptBin "run-in-podman" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              set -x
              mkdir -p ./tmp
              export HOME=./tmp

              ${pkgs.strace}/bin/strace ${pkgs.podman}/bin/podman run --rm --detach ${podman.imageName}:${podman.imageTag}

              id=$(${pkgs.podman}/bin/podman run --rm --detach ${podman.imageName}:${podman.imageTag})
              sleep 2
              ${pkgs.podman}/bin/podman exec $id "$@"
            '';
        };

        mkPublishOCIScript = {
          type = types.functionTo types.package;
          description = "Build publishing script for CI that pushes container images to registry";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              container = perSystemConfig.containers.${containerId};
              oci = perSystemConfig.internal.OCIs.${containerId};
              tags = container.tags;
            in
            pkgs.writeScriptBin "publish-docker-image-${containerId}" ''
              #!${pkgs.bash}/bin/bash

              set -o errexit
              set -o nounset
              set -o pipefail

              main() {
                echo "Authenticating to the registry..."
                echo "$CI_REGISTRY_PASSWORD" | ${perSystemConfig.packages.skopeo}/bin/skopeo login --username "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"

                ${lib.concatMapStrings (tag: ''
                  local image_path="$CI_REGISTRY_IMAGE/${container.name}:${tag}"
                  echo "Pushing image $image_path to the registry..."
                  ${perSystemConfig.packages.skopeo}/bin/skopeo copy \
                    nix:${oci} \
                    docker://$image_path
                  echo "Image pushed to $image_path"
                '') tags}
              }

              main "$@"
            '';
        };
      };
    };
}
