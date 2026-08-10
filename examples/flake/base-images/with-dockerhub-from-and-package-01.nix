# Example: Base image with an additional Nix package
#
# Demonstrates pulling a Docker Hub base image and layering a Nix package
# (hello) on top, combining upstream images with Nix-built software.
#
# Options used:
#   - oci.containers.<name>.fromImage (pull a remote image as base layer)
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#
# Usage:
#   nix build .#oci-withDockerHubFromAndPackage
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndPackage = {
            package = pkgs.hello;
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
