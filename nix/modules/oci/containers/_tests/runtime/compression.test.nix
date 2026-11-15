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
      };

      # Deliberately a SEPARATE group from the zstd scenario above, not
      # a second scenario inside it.
      #
      # Specs are sharded by group, and one shard is one VM with one
      # local registry. Keeping both scenarios in one group put a
      # non-turbo zstd push and a turbo estargz push in the same
      # session, and nix2container-turbo's cross-push layer cache
      # reuses a cached compressed blob keyed purely on source digest
      # with no check that the cached format matches the requested one
      # (its own destination/soci_wrap.go). Every nix2container image
      # shares at least one small bootstrap-metadata layer regardless
      # of package, so whichever push ran first decided the format for
      # that shared layer and the second silently inherited it.
      #
      # Observed live: estargz's manifest came back `+zstd`, failing
      # this scenario, on CI runs 43739248076 and 43750594601, while
      # the identical commit passed on 43727324923 and 43744806100.
      # Flaky on push ordering, which is why it survived so long.
      #
      # The previous mitigation only kept this group away from
      # performance-turbo-soci-runtime's turbo pushes. That was not
      # enough, because the collision never needed a second SPEC: the
      # group's own two pushes collided with each other. Splitting the
      # group is what actually separates the sessions.
      test.oci.perContainer.performance-compression-estargz-runtime = {
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
            # Package choice is incidental: every nix2container image
            # shares at least one small bootstrap-metadata layer
            # regardless of package, so swapping busybox for this did
            # not on its own stop the collision. The fix is the group
            # split documented above, which puts this turbo push in a
            # VM of its own.
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
          # Repository follows the spec key `<group>--<scenario>`, so
          # it tracks the group rename above.
          assertions.compressionApplied = {
            registry = "localhost:5000";
            repository = "performance-compression-estargz-runtime--runtime-estargz-layers";
            tag = "latest";
            family = "gzip";
          };
        };
      };
    };
}
