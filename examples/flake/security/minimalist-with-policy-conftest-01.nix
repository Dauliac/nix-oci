# Example: Minimalist container with Conftest OCI policy checking
#
# Runs `conftest` against the built image's OCI config to validate
# security policies (no root user, no leaked secrets, labels, etc.).
#
# Usage:
#   nix run .#oci-policy-conftest-minimalistWithPolicyConftest
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithPolicyConftest = {
            package = pkgs.hello;
            policy.conftest.enabled = true;
          };
        };
      };
  };
}
