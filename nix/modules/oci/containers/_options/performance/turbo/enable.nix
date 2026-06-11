# Shared: nix2container-turbo push backend.
#
# When enabled, uses turbo-patched skopeo for image pushes, providing
# cross-machine layer caching via OCI Referrers API and optional SOCI v2
# index generation for lazy pulling.
#
# References:
#   - https://github.com/schlarpc/nix2container-turbo
{
  lib,
  pkgs,
  ...
}:
let
  example = true;
in
{
  options.performance.turbo.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Use nix2container-turbo patched skopeo for image pushes.

      Enables cross-machine layer caching via OCI Referrers API: layer
      mappings (nix store hash → compressed digest) are stored in the
      registry so any machine can skip re-compressing and re-uploading
      unchanged layers. Repushes become sub-second regardless of image size.

      Requires an OCI registry supporting the Referrers API
      (ECR, GHCR, Docker Hub, and most modern registries).
    '';
    inherit example;
  };

  config._tests.performance-turbo-enable = {
    level = "eval";
    default = {
      package = pkgs.hello;
      performance.enable = true;
    };
    override = {
      package = pkgs.hello;
      performance.enable = true;
      performance.turbo.enable = example;
    };
  };
}
