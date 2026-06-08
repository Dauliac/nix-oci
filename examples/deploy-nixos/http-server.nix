# Example: NixOS deploy configuration for nix-oci.
#
# Loads an OCI image into podman and auto-starts it via virtualisation.oci-containers.
# The `testImage` argument is the nix2container buildImage output.
#
# Usage in a NixOS configuration:
#   imports = [
#     inputs.nix-oci.modules.nixos.nix-oci
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
      autoStart = true;
    };
  };

  virtualisation.oci-containers.containers.test-http = {
    ports = [ "8080:8080" ];
  };
}
