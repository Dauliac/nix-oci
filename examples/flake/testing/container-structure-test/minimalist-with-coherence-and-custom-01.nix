# Example: CST coherence + custom user-supplied tests
#
# Auto-generated coherence checks run alongside user-supplied CST
# configs. The coherence test validates metadata; the custom YAML
# adds filesystem and command tests.
#
# Usage:
#   nix run .#oci-container-structure-test-minimalistWithCoherenceAndCustom
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithCoherenceAndCustom = {
            package = pkgs.kubectl;
            test.containerStructureTest = {
              enabled = true;
              # coherence = true (default) auto-generates metadata checks
              # user-supplied YAML adds filesystem/command checks on top
              configs = [ ./test.yaml ];
            };
          };
        };
      };
  };
}
