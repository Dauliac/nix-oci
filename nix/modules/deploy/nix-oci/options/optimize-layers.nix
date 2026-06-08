# Override optimizeLayers default to true for deploy-targeted builds.
#
# When images are loaded into a local container runtime (NixOS/home-manager),
# atomic layering is beneficial because:
# - No push cost (layers are only copied locally)
# - Shared layers across containers reduce disk usage on the machine
# - Rebuild of one container reuses cached layers from others
#
# This sets a low-priority default (mkDefault) — users can still explicitly
# set `optimizeLayers = false` per container to override.
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      oci.perContainer =
        { ... }:
        {
          config.optimizeLayers = lib.mkDefault true;
        };
    };
}
