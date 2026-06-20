# Shared: OCI layer compression algorithm.
#
# nix2container delegates compression to skopeo at transport time.
# zstd is 3-5x faster than gzip with 12% better compression ratios.
#
# References:
#   - OCI Image Spec v1.1 (zstd support)
#   - https://aws.amazon.com/blogs/containers/reducing-aws-fargate-startup-times-with-zstd-compressed-container-images/
#   - https://github.com/schlarpc/nix2container-turbo (eStargz support)
{ lib, ... }:
let
  example = "zstd";
in
{
  options.performance.compression = lib.mkOption {
    type = lib.types.enum [
      "gzip"
      "zstd"
      "gzip:estargz"
    ];
    default = "gzip";
    description = ''
      Compression algorithm for OCI image layers during transport (skopeo).

      - `"gzip"` -- universal compatibility, slower.
      - `"zstd"` -- 3-5x faster compress/decompress, 12% smaller.
        Requires OCI 1.1+ registry (Docker Hub, ECR, GCR, GHCR support it).
        containerd 2.0+ required; containerd 1.7.x does NOT support zstd.
      - `"gzip:estargz"` -- eStargz format for lazy pulling with stargz-snapshotter.
        Requires `performance.turbo.enable = true`.
        Cannot be combined with SOCI (`performance.turbo.soci`).
    '';
    inherit example;
  };
}
