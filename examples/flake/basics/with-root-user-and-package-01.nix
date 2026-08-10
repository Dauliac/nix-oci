# Example: Container running as root with dependencies
#
# Demonstrates building a container that runs as root and includes extra
# runtime dependencies beyond the main package.
#
# Options used:
#   - oci.containers.<name>.package (main entrypoint package)
#   - oci.containers.<name>.dependencies (additional packages in the image)
#   - oci.containers.<name>.isRoot (run the container as root)
#
# Usage:
#   nix build .#oci-withRootUserAndPackage
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withRootUserAndPackage = {
            package = pkgs.bash;
            dependencies = [
              pkgs.coreutils
            ];
            isRoot = true;
          };
        };
      };
  };
}
