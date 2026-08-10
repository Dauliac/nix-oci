# Example: Pull a base image from Docker Hub
#
# Demonstrates using fromImage to pull an existing Docker Hub image (Alpine)
# as the base layer for your OCI container.
#
# Options used:
#   - oci.containers.<name>.fromImage (pull a remote image as base layer)
#
# Usage:
#   nix build .#oci-withDockerHubFrom
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFrom = {
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
