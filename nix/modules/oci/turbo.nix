# Global turbo push backend configuration.
#
# These options set the fleet-wide defaults for nix2container-turbo.
# Per-container options (performance.turbo.*) inherit from these defaults
# and can be overridden individually.
#
# References:
#   - https://github.com/schlarpc/nix2container-turbo
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { ... }:
    {
      options.oci.turbo = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Use nix2container-turbo patched skopeo for all container pushes.

            Enables cross-machine layer caching via OCI Referrers API by default.
            Per-container overrides: `oci.containers.<name>.performance.turbo.enable`.
          '';
          example = true;
        };

        soci = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Generate SOCI v2 indexes during push for all containers.

            Enables lazy pulling on AWS ECS/Fargate and containerd with
            soci-snapshotter.
            Per-container overrides: `oci.containers.<name>.performance.turbo.soci`.
          '';
          example = true;
        };

        sociSpanSize = mkOption {
          type = types.int;
          default = 4194304;
          description = ''
            Default SOCI span size in bytes for all containers.

            Per-container overrides: `oci.containers.<name>.performance.turbo.sociSpanSize`.
          '';
          example = 4194304;
        };

        layerCache = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Enable cross-machine layer caching via OCI Referrers API for all containers.

            Per-container overrides: `oci.containers.<name>.performance.turbo.layerCache`.
          '';
          example = true;
        };
      };
    }
  );
}
