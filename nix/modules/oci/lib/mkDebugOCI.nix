# OCI mkDebugOCI - Build a debug variant of a container with additional packages
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
      nix-lib.lib.oci.mkDebugOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a debug variant of a container with additional packages";
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            debugConfig = {
              tag = oci.tag + "-debug";
              dependencies = oci.dependencies ++ oci.debug.packages;
              entrypoint =
                if oci.debug.entrypoint.enabled then
                  [ "${oci.debug.entrypoint.wrapper}/bin/entrypoint" ] ++ oci.entrypoint
                else
                  oci.entrypoint;
            };
            perSystemConfig' = perSystemConfig // {
              containers = perSystemConfig.containers // {
                ${containerId} = oci // debugConfig;
              };
            };
          in
          ociLib.mkNixOrSimpleOCI {
            perSystemConfig = perSystemConfig';
            inherit containerId globalConfig;
          };
      };
    };
}
