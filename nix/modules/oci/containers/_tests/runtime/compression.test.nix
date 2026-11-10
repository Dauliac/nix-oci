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
            # Package choice here is incidental, not the fix: every
            # nix2container image shares at least one small bootstrap-
            # metadata layer regardless of package (confirmed live --
            # swapping busybox for this distinct package did NOT, on
            # its own, stop the collision below). The actual fix is
            # keeping this whole group out of any shard that also runs
            # performance-turbo-soci-runtime's turbo pushes -- see
            # performanceShardOverride's comment in test-vm.nix for the
            # full explanation of nix2container-turbo's layer-cache
            # format-blind reuse.
            package = pkgs.hello;
            isRoot = true;
            performance.enable = true;
            performance.turbo.enable = true;
            performance.compression = "gzip:estargz";
            # estargz embeds a TOC that changes the layer's uncompressed
            # bytes, so its digest no longer matches the DiffID
            # nix2container recorded in the image config at build time.
            # A plain (non-stargz-aware) `podman pull` enforces that
            # match strictly and rejects the image -- eStargz is meant
            # for lazy pulling via a stargz-aware snapshotter, not a
            # normal pull-and-run. This scenario only needs the push,
            # which compressionApplied verifies directly against the
            # registry.
            autoStart = false;
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
