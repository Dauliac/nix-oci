# Shared: SOCI v2 index generation for lazy pulling.
#
# Generates SOCI (Seekable OCI) v2 indexes inline during push.
# Enables lazy pulling on AWS ECS/Fargate and containerd with
# soci-snapshotter — containers start before the full image is downloaded.
#
# References:
#   - https://github.com/awslabs/soci-snapshotter
#   - https://aws.amazon.com/blogs/aws/aws-fargate-enables-faster-container-startup-using-seekable-oci/
{
  lib,
  pkgs,
  perSystemConfig,
  ...
}:
let
  example = true;
  globalTurbo = perSystemConfig.oci.turbo or { };
in
{
  options.performance.turbo.soci = lib.mkOption {
    type = lib.types.bool;
    default = globalTurbo.soci or false;
    description = ''
      Generate SOCI v2 indexes during push for lazy pulling.

      When enabled, the turbo-patched skopeo generates zTOC (table of
      contents) for each layer during push and bundles them into a SOCI v2
      index manifest alongside the image in an OCI Index.

      Reduces cold-start times significantly for large images on
      AWS ECS/Fargate (~53s → ~20s for a 1GB image).

      Requires `performance.turbo.enable = true` and gzip compression
      (SOCI does not support zstd). eStargz and SOCI cannot be combined.
    '';
    inherit example;
  };

  config._tests.performance-turbo-soci = {
    level = "eval";
    default = {
      package = pkgs.hello;
      performance.enable = true;
      performance.turbo.enable = true;
    };
    override = {
      package = pkgs.hello;
      performance.enable = true;
      performance.turbo.enable = true;
      performance.turbo.soci = example;
    };
  };
}
