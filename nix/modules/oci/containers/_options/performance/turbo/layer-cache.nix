# Shared: cross-machine layer caching via OCI Referrers.
#
# When turbo is enabled, layer mappings (nix source digest → compressed
# digest + optional zTOC) are stored as OCI referrer manifests in the
# registry. Any machine pushing the same image can look up these mappings
# and skip re-compression and re-upload entirely.
#
# References:
#   - https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers
{
  lib,
  pkgs,
  ...
}:
let
  example = true;
in
{
  options.performance.turbo.layerCache = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Enable cross-machine layer caching via OCI Referrers API.

      Stores nix store path → compressed layer mappings as referrer manifests
      in the registry. Subsequent pushes from any machine look up these
      mappings and skip re-compression and re-upload for unchanged layers.

      Achieves sub-second repush times regardless of image size.

      Enabled by default when `performance.turbo.enable = true`.
      Requires an OCI registry supporting the Referrers API.
    '';
    inherit example;
  };

  config._tests.performance-turbo-layer-cache = {
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
      performance.turbo.layerCache = example;
    };
  };
}
