# Example: home-manager deploy configuration for nix-oci.
#
# Loads an OCI image into rootless podman via user systemd services.
# The `testImage` argument is the nix2container buildImage output.
#
# Usage in a home-manager configuration:
#   imports = [
#     inputs.nix-oci.modules.homeManager.nix-oci
#     (import ./http-server.nix { testImage = myImage; })
#   ];
{ testImage }:
{ ... }:
{
  services.nix-oci = {
    enable = true;
    backend = "podman";
    containers.test-http = {
      image = testImage;
    };
  };
}
