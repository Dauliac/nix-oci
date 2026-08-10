# Example: Container from writeShellApplication
#
# Demonstrates using pkgs.writeShellApplication to create an inline shell
# script with runtime dependencies as the container's entrypoint.
#
# Options used:
#   - oci.containers.<name>.package (writeShellApplication derivation)
#
# Usage:
#   nix build .#oci-write-shell-application
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
          write-shell-application = {
            package = pkgs.writeShellApplication {
              name = "hello-app";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                echo "Hello from writeShellApplication!"
                whoami
              '';
            };
          };
        };
      };
  };
}
