# Runtime BDD test specs for performance.turbo.soci.
#
# Verifies that pushing a SOCI-enabled container to the in-VM local
# registry attaches a SOCI v2 zTOC referrer manifest to the image, and
# that the configured span size is honoured by the generated zTOC.
#
# The test.oci.testing.registry infrastructure boots a local registry
# inside the VM; the SOCI assertion queries the /v2/<repo>/referrers/
# endpoint to confirm the zTOC is attached and (optionally) inspects
# it with the `soci` CLI to verify span size.
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: SOCI zTOC is generated
#   Scenario: SOCI span size is applied
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-turbo-soci-runtime = {
        # Default 4 MiB span: only assert the referrer manifest exists.
        runtime-soci-referrer-present = {
          given = "a container with performance.turbo.soci = true pushed to the in-VM registry";
          "when" = "the OCI referrers API is queried for the image tag";
          "then" = "a SOCI v2 zTOC referrer manifest is attached to the image";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.turbo.enable = true;
            performance.turbo.soci = true;
            # gzip is the only compression SOCI supports; leaving default.
          };
          assertions.sociZtocPresent = {
            registry = "localhost:5000";
            repository = "performance-turbo-soci-runtime--runtime-soci-referrer-present";
            tag = "latest";
            # spanSize left null -> only presence of the referrer is asserted.
          };
        };

        # Explicit 1 MiB span: assert the span size decoded from the zTOC.
        runtime-soci-span-size-1MiB = {
          given = "a container with performance.turbo.soci = true and sociSpanSize = 1 MiB";
          "when" = "the SOCI zTOC is inspected via the referrers API";
          "then" = "the zTOC records the 1 MiB span size";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.turbo.enable = true;
            performance.turbo.soci = true;
            performance.turbo.sociSpanSize = 1048576;
          };
          assertions.sociZtocPresent = {
            registry = "localhost:5000";
            repository = "performance-turbo-soci-runtime--runtime-soci-span-size-1mib";
            tag = "latest";
            spanSize = "1MiB";
          };
        };
      };
    };
}
