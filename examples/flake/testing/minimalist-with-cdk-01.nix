# Example: Minimalist container with CDK security auditing
#
# Runs `cdk evaluate` inside the container (bind-mounted, not baked
# in) to enumerate escape vectors, capabilities, service accounts,
# sensitive files, and mounted devices.
#
# Usage:
#   nix run .#oci-cdk-minimalistWithCdk
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithCdk = {
            package = pkgs.hello;
            test.cdk.enabled = true;
          };
        };
      };
  };
}
