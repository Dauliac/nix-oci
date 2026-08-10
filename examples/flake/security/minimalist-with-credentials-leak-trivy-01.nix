# Example: Credentials leak scanning with Trivy
#
# Demonstrates enabling Trivy-based credentials leak detection to scan
# the built image for accidentally embedded secrets or API keys.
#
# Options used:
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#   - oci.containers.<name>.credentialsLeak.trivy.enabled (enable leak scanning)
#
# Usage:
#   nix build .#oci-minimalistWithCredentialsLeaksTrivy
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
          minimalistWithCredentialsLeaksTrivy = {
            package = pkgs.kubectl;
            credentialsLeak.trivy = {
              enabled = true;
            };
          };
        };
      };
  };
}
