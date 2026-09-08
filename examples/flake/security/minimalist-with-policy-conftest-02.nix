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
            # `./conftest/labels.rego` requires a `team` label — set it here
            # so the example demonstrates a *passing* policy check.
            labels."team" = "platform";
            policy.conftest = {
              enabled = true;
              policyDir = ./conftest;
            };
          };
        };
      };
  };
}
