# Runtime BDD test specs for performance.compression.
#
# Verifies the compression algorithm applied to layer descriptors in
# the built OCI manifest:
#   - "zstd"          -> every layer mediaType ends in `+zstd`
#   - "gzip:estargz"  -> layers use gzip with estargz TOC entries
#
# performance.compression is only ever actually applied via skopeo's
# --dest-compress-format flag at push time (see mkPushApp.nix,
# load-services.nix) -- there is no build-time or direct-podman-load
# equivalent, so these scenarios push through the local registry
# (oci.registry.enable, via the compressionApplied assertion) rather
# than inspecting a direct podman load, which would never show the
# configured compression applied at all.
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: Compression algorithm applied to layers
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-compression-runtime = {
        # zstd: every layer descriptor mediaType ends with `+zstd`.
        runtime-zstd-layers = {
          given = "a container built with performance.compression = \"zstd\"";
          "when" = "the container is pushed to the local registry and its OCI manifest layers are inspected";
          "then" = "every layer descriptor mediaType ends in +zstd";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.compression = "zstd";
          };
          assertions.compressionApplied = {
            registry = "localhost:5000";
            repository = "performance-compression-runtime--runtime-zstd-layers";
            tag = "latest";
            family = "zstd";
          };
        };

        # gzip:estargz: layer mediaTypes remain gzip (+gzip) but the
        # image gains estargz TOC entries. Verify at least one layer's
        # mediaType matches the gzip family.
        runtime-estargz-layers = {
          given = "a container built with performance.compression = \"gzip:estargz\"";
          "when" = "the container is pushed to the local registry and its OCI manifest layers are inspected";
          "then" = "layers use the gzip mediaType family (estargz stacks on gzip)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.turbo.enable = true;
            performance.compression = "gzip:estargz";
          };
          assertions.compressionApplied = {
            registry = "localhost:5000";
            repository = "performance-compression-runtime--runtime-estargz-layers";
            tag = "latest";
            family = "gzip";
          };
        };
      };
    };
}
