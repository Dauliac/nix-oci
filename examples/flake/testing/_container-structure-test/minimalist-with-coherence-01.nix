# Example: CST coherence checking (auto-generated from module config)
#
# No user-supplied CST YAML needed. nix-oci auto-generates a
# metadataTest config that validates the built artifact matches the
# declared user, entrypoint, ports, labels, and environment.
#
# Usage:
#   nix run .#oci-container-structure-test-minimalistWithCoherence
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithCoherence = {
            package = pkgs.hello;
            entrypoint = [ "/bin/hello" ];
            ports = [ "8080:8080" ];
            labels = {
              "org.opencontainers.image.title" = "coherence-example";
            };
            environment = {
              GREETING = "world";
            };
            test.containerStructureTest = {
              enabled = true;
              # coherence = true is the default — no YAML file needed
            };
          };
        };
      };
  };
}
