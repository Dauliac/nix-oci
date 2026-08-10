# Example: Container from writeShellScriptBin
#
# Demonstrates using pkgs.writeShellScriptBin to create a simple inline
# shell script as the container's entrypoint package.
#
# Options used:
#   - oci.containers.<name>.package (writeShellScriptBin derivation)
#
# Usage:
#   nix build .#oci-write-shell-script-bin
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
          write-shell-script-bin = {
            package = pkgs.writeShellScriptBin "hello-script" ''
              echo "Hello from writeShellScriptBin!"
            '';
          };
        };
      };
  };
}
