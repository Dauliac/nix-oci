# Example: enable Conftest OCI policy checking.
#
# Runs `conftest` against the built image's OCI config to validate
# security policies (no root user, no leaked secrets, labels, etc.).
#
# Usage:
#   nix run .#oci-policy-conftest-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            policy.conftest.enabled = true;
          };
        };
      };
  };
}
