# Runtime BDD test specs for performance.compression.
#
# Verifies the compression algorithm applied to layer descriptors in
# the built OCI manifest:
#   - "zstd"          -> every layer mediaType ends in `+zstd`
#   - "gzip:estargz"  -> layers use gzip with estargz TOC entries
#
# Layer mediaTypes live in the OCI image manifest (`.layers[].mediaType`),
# not in `Config`. The runtime escape hatch drops into raw pytest to
# query the manifest via the Docker SDK's low-level image inspect.
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
          "when" = "the OCI manifest layers are inspected";
          "then" = "every layer descriptor mediaType ends in +zstd";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.compression = "zstd";
          };
          assertions.runtime = ''
            # zstd layer mediaType check via low-level manifest inspect.
            _img = client.images.get("performance-compression-runtime--runtime-zstd-layers:latest")
            _manifest = _img.attrs.get("Manifest") or {}
            _layers = _manifest.get("layers") or []
            # Fallback: docker/podman may expose RootFS with layer digests
            # only; parse the OCI manifest via the API if needed.
            if not _layers:
                # Try low-level API for the manifest blob.
                import json, subprocess
                _raw = subprocess.check_output([
                    "podman", "image", "inspect", "--format", "{{json .Manifest}}",
                    "performance-compression-runtime--runtime-zstd-layers:latest",
                ])
                try:
                    _manifest = json.loads(_raw)
                    _layers = _manifest.get("layers") or []
                except Exception:
                    pass
            assert _layers, "expected at least one layer in the manifest"
            for _l in _layers:
                _mt = _l.get("mediaType", "")
                assert _mt.endswith("+zstd"), (
                    f"expected zstd layer, got mediaType={_mt!r}"
                )
          '';
        };

        # gzip:estargz: layer mediaTypes remain gzip (+gzip) but the
        # image gains estargz TOC entries. Verify at least one layer's
        # mediaType matches the gzip family.
        runtime-estargz-layers = {
          given = "a container built with performance.compression = \"gzip:estargz\"";
          "when" = "the OCI manifest layers are inspected";
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
          assertions.runtime = ''
            import json, subprocess
            _raw = subprocess.check_output([
                "podman", "image", "inspect", "--format", "{{json .Manifest}}",
                "performance-compression-runtime--runtime-estargz-layers:latest",
            ])
            _manifest = json.loads(_raw)
            _layers = _manifest.get("layers") or []
            assert _layers, "expected at least one layer in the manifest"
            _gzip_family = (
                "application/vnd.oci.image.layer.v1.tar+gzip",
                "application/vnd.docker.image.rootfs.diff.tar.gzip",
            )
            for _l in _layers:
                _mt = _l.get("mediaType", "")
                assert _mt in _gzip_family, (
                    f"expected gzip-family layer for estargz, got mediaType={_mt!r}"
                )
          '';
        };
      };
    };
}
