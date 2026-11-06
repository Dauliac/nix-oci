# Runtime BDD test specs for performance.turbo.soci.
#
# Verifies that pushing a SOCI-enabled container to the in-VM local
# registry attaches a SOCI v2 zTOC index to the image, and that the
# configured span size is honoured by the generated zTOC.
#
# The test.oci.testing.registry infrastructure boots a local registry
# inside the VM; the push uses nix2container-turbo's SOCI v2 format,
# which does NOT use the OCI Referrers API -- it pushes a top-level
# OCI Index at the tag containing both the real image manifest and a
# second entry (artifactType application/vnd.amazon.soci.index.v2+json)
# pointing at a SOCI index manifest whose `.layers[]` are the zTOC
# descriptors, each annotated with its span size. The SOCI assertion
# fetches that index and walks it (see _python-gen.nix:mkSociZtocPresent).
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
        # Default 4 MiB span: only assert the SOCI index is present.
        runtime-soci-referrer-present = {
          given = "a container with performance.turbo.soci = true pushed to the in-VM registry";
          "when" = "the OCI Index at the image tag is inspected";
          "then" = "a SOCI v2 zTOC index manifest is attached alongside the image manifest";
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
            # spanSize left null -> only presence of the zTOC index is asserted.
          };
        };

        # Explicit 1 MiB span: assert the span size decoded from the zTOC.
        runtime-soci-span-size-1MiB = {
          given = "a container with performance.turbo.soci = true and sociSpanSize = 1 MiB";
          "when" = "the SOCI zTOC is inspected via the SOCI v2 index manifest";
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
            # Must match container.performance.turbo.sociSpanSize above
            # (bytes, not a display string -- see _python-gen.nix).
            spanSize = 1048576;
          };
        };
      };
    };
}
