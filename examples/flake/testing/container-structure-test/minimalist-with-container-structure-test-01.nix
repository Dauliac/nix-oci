# Example: Container Structure Test
#
# Demonstrates enabling Google's Container Structure Test to validate the
# built image's metadata, commands, and file contents match expectations.
#
# Options used:
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#   - oci.containers.<name>.test.containerStructureTest.enabled (enable CST)
#
# Usage:
#   nix build .#oci-minimalistWithContainerStructureTest
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
          minimalistWithContainerStructureTest = {
            package = pkgs.kubectl;
            test.containerStructureTest.enabled = true;
          };
        };
      };
  };
}
