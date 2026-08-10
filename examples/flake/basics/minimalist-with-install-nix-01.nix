# Example: Container with Nix installed
#
# Demonstrates building a container with the Nix package manager available
# inside. Useful for CI containers or development environments.
#
# Options used:
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#   - oci.containers.<name>.installNix (initialize the Nix database in the image)
#
# Usage:
#   nix build .#oci-minimalist-with-install-nix
{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        config.oci.containers = {
          minimalist-with-install-nix = {
            package = pkgs.kubectl;
            installNix = true;
          };
        };
      };
  };
}
