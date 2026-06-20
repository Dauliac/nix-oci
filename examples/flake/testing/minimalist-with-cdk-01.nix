# Example: enable CDK container exploitation toolkit probe.
#
# Runs `cdk` inside the container (bind-mounted, static binary)
# to detect container exploit vectors.
#
# Usage:
#   nix run .#oci-cdk-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            test.cdk.enabled = true;
          };
        };
      };
  };
}
