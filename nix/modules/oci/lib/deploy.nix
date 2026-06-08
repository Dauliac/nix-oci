# Register deploy lib functions in the flake-parts nix-lib system.
#
# Makes `skopeoDestPrefix`, `mkImageRef`, `mkLoadServiceName`, and
# `copyScript` available as typed, documented functions via
# `config.lib.oci.*` in perSystem.
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci = {
        skopeoDestPrefix = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Return the skopeo destination prefix for a container backend.
            `"docker"` → `"docker-daemon:"`, `"podman"` → `"containers-storage:"`.
          '';
          fn = backend: if backend == "docker" then "docker-daemon:" else "containers-storage:";
        };

        mkImageRef = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Compute an OCI image reference (`"name:tag"`) from a nix2container
            `buildImage` derivation and a fallback name.
          '';
          fn =
            {
              image,
              name,
            }:
            let
              imageName = image.imageName or name;
              imageTag = image.imageTag or "latest";
            in
            "${imageName}:${imageTag}";
        };

        mkLoadServiceName = {
          type = lib.types.functionTo lib.types.str;
          description = "Compute the systemd service name for a container load unit.";
          fn = name: "nix-oci-load-${name}";
        };

        copyScript = {
          type = lib.types.functionTo lib.types.package;
          description = ''
            Select the nix2container passthru copy script for a given backend.
            Returns a derivation (executable script) that bundles `skopeo-nix2container`.
          '';
          fn =
            {
              backend,
              image,
            }:
            if backend == "docker" then image.copyToDockerDaemon else image.copyToPodman;
        };
      };
    };
}
