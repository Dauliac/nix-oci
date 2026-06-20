# Example: Container with Conftest policy checking and custom policy directory
#
# Demonstrates per-container configuration with a custom Rego policy
# directory and additional namespaces.
#
# Usage:
#   nix run .#oci-policy-conftest-minimalistWithCustomPolicy
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithCustomPolicy = {
            package = pkgs.hello;
            policy.conftest = {
              enabled = true;
              policyDir = ./conftest;
            };
          };
        };
      };
  };
}
