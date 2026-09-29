# BDD spec for performance label coherence (z83.7.18).
#
# Covers spec `Requirement: Performance label coherence`:
#   performance.allocator, performance.turbo, performance.turbo-soci
#   labels reflect the enabled performance features.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-label-performance = {
        inspect-allocator-label = {
          given = "a container with performance.enable=true and allocator=jemalloc";
          "when" = "the OCI image is inspected";
          "then" = "performance.allocator label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            performance = {
              enable = true;
              allocator = "jemalloc";
            };
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.performance.enabled" = "true";
            "io.github.dauliac.nix-oci.performance.allocator" = "jemalloc";
          };
        };

        inspect-turbo-soci-label = {
          given = "a container with performance.turbo.enable and performance.turbo.soci";
          "when" = "the OCI image is inspected";
          "then" = "performance.turbo-soci label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            performance = {
              enable = true;
              turbo = {
                enable = true;
                soci = true;
              };
            };
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.performance.turbo" = "true";
            "io.github.dauliac.nix-oci.performance.turbo-soci" = "true";
          };
        };

        inspect-no-performance-labels-when-disabled = {
          given = "a container with performance.enable=false (default)";
          "when" = "the OCI image is inspected";
          "then" =
            "no performance.* label is present (spec-declared; deep negative-key check requires future assertion helper)";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          # The imageConfig.Labels submap check is inclusion-based; a
          # dedicated "label absent" assertion is tracked with the
          # section-1 typed helper set. Spec presence keeps the
          # scenario discoverable and the container definition ready
          # for the stronger check when the helper lands.
        };
      };
    };
}
