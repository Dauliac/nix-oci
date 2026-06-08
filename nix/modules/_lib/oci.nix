# Shared OCI deploy library — typed, documented function definitions.
#
# Each entry follows the nix-lib convention: { type, description, fn }.
# This single source of truth is consumed by:
#   - flake-parts:    registered as `nix-lib.lib.oci.*` (typed, testable, documented)
#   - NixOS module:   wrapped as `config.services.nix-oci.lib.*` (partially applied with cfg)
#   - home-manager:   same as NixOS (shared via _generic/)
#
# Usage:
#   let deployDefs = import ./_lib/oci.nix { inherit lib; }; in ...
{ lib }:
{
  skopeoDestPrefix = {
    type = lib.types.functionTo lib.types.str;
    description = ''
      Return the skopeo destination prefix for a container backend.

      - `"docker"` → `"docker-daemon:"` (Docker Engine local store)
      - `"podman"` → `"containers-storage:"` (Podman/CRI-O local store)
    '';
    fn = backend: if backend == "docker" then "docker-daemon:" else "containers-storage:";
  };

  mkImageRef = {
    type = lib.types.functionTo lib.types.str;
    description = ''
      Compute an OCI image reference (`"name:tag"`) from a nix2container
      `buildImage` derivation and a fallback name (typically the attrset key).

      Reads `image.imageName` / `image.imageTag` passthru attributes,
      falling back to the provided `name` and `"latest"`.
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
    description = ''
      Compute the systemd service name for a container load unit.

      Example: `mkLoadServiceName "redis"` → `"nix-oci-load-redis"`.
    '';
    fn = name: "nix-oci-load-${name}";
  };

  copyScript = {
    type = lib.types.functionTo lib.types.package;
    description = ''
      Select the nix2container passthru copy script for a given backend.

      nix2container `buildImage` provides `copyToDockerDaemon` and
      `copyToPodman` scripts that bundle `skopeo-nix2container` (the
      patched skopeo with `nix:` transport support). This function
      selects the right one based on the backend.

      Returns a derivation (executable script path).
    '';
    fn =
      {
        backend,
        image,
      }:
      if backend == "docker" then image.copyToDockerDaemon else image.copyToPodman;
  };
}
