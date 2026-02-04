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
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            installNix = oci.installNix or false;
          in
          if installNix then
            ociLib.mkNixOCI { inherit perSystemConfig containerId; }
          else
            ociLib.mkSimpleOCI { inherit perSystemConfig containerId globalConfig; };
      };
    };
}
