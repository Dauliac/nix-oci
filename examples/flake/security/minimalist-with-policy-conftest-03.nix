# Example: Conftest policy composition with extraPolicyDirs
#
# Extends the built-in nix-oci policies with a custom directory of Rego
# rules. Both built-in rules (no root, no secrets, entrypoint check) and
# custom rules (team label, naming) run together.
#
# Usage:
#   nix run .#oci-policy-conftest-minimalistWithExtraPolicies
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithExtraPolicies = {
            package = pkgs.hello;
            labels.team = "platform";
            policy.conftest = {
              enabled = true;
              extraPolicyDirs = [ ./conftest ];
            };
          };
        };
      };
  };
}
