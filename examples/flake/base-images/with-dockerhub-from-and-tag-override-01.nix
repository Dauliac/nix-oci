# Example: Base image with custom tag
#
# Demonstrates pulling a Docker Hub base image while overriding the output
# image tag, useful for versioning your derived images independently.
#
# Options used:
#   - oci.containers.<name>.fromImage (pull a remote image as base layer)
#   - oci.containers.<name>.tag (override the output image tag)
#
# Usage:
#   nix build .#oci-withDockerHubFromAndTagOverride
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndTagOverride = {
            tag = "1.1.0";
            fromImage = {
              imageName = "library/alpine";
              imageTag = "3.21.2";
            };
          };
        };
      };
  };
}
