# Example: enable Syft SBOM generation.
#
# Generates a software bill of materials (SBOM) for the built image.
#
# Usage:
#   nix run .#oci-sbom-syft-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            sbom.syft.enabled = true;
          };
        };
      };
  };
}
