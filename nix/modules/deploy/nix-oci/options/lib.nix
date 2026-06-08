# services.nix-oci.lib — internal helpers, registered for both NixOS and home-manager.
#
# Functions are defined inline (same implementations registered in
# flake-parts nix-lib via oci/lib/deploy.nix).
{ ... }:
let
  mod =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.nix-oci;
    in
    {
      options.services.nix-oci.lib = {
        mkImageRef = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Compute an OCI image reference (`"name:tag"`) from a nix2container
            `buildImage` derivation and a fallback name.
          '';
          internal = true;
          readOnly = true;
          default =
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

        mkLoadServiceName = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          description = "Compute the systemd service name for a container load unit.";
          internal = true;
          readOnly = true;
          default = name: "nix-oci-load-${name}";
        };

        # Partially applied with cfg.backend.
        # Returns the nix2container passthru copy script (bundles skopeo-nix2container).
        copyScript = lib.mkOption {
          type = lib.types.unspecified;
          description = ''
            Select the nix2container passthru copy script for the configured backend.
          '';
          internal = true;
          readOnly = true;
          default =
            { container }:
            if cfg.backend == "docker" then
              container.image.copyToDockerDaemon
            else
              container.image.copyToPodman;
        };
      };
    };
in
{
  flake.modules.nixos.nix-oci-lib = mod;
  flake.modules.homeManager.nix-oci-lib = mod;
}
