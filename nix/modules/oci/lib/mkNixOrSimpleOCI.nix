# DEPRECATED: Use mkOCIImage instead. This function is kept for backward compat.
# OCI mkNixOrSimpleOCI - Build either a Nix or simple container depending on config
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkNixOrSimpleOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build either a Nix or simple container depending on config";
        file = "nix/modules/oci/lib/mkNixOrSimpleOCI.nix";
        fn =
          {
            perSystemConfig,
            containerId,
            ...
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            installNix = oci.installNix or false;
          in
          if installNix then
            ociLib.mkNixOCI { inherit perSystemConfig containerId; }
          else
            ociLib.mkSimpleOCI { inherit perSystemConfig containerId; };
      };
    };
}
