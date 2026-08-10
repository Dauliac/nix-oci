# Example: Base image with custom name and tag
#
# Demonstrates pulling a Docker Hub base image while overriding both the
# output image name and tag to publish under a custom identity.
#
# Options used:
#   - oci.containers.<name>.fromImage (pull a remote image as base layer)
#   - oci.containers.<name>.name (override the output image name)
#   - oci.containers.<name>.tag (override the output image tag)
#
# Usage:
#   nix build .#oci-withDockerHubFromAndNameAndTagOverride
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withDockerHubFromAndNameAndTagOverride = {
            name = "my-alpine";
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
