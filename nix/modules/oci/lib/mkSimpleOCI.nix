# OCI mkSimpleOCI - Build a simple container without Nix support
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
      nix-lib.lib.oci.mkSimpleOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a simple container without Nix support";
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;
            fromImage =
              if !oci.fromImage.enabled then
                ""
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId globalConfig;
                };
          in
          perSystemConfig.packages.nix2container.buildImage {
            inherit (oci) tag;
            name = fullName;
            inherit fromImage;
            copyToRoot = [
              (ociLib.mkRoot {
                inherit (oci)
                  package
                  dependencies
                  tag
                  user
                  ;
              })
            ];
            config = {
              inherit (oci) entrypoint;
              User = oci.user;
              Env = [
                "PATH=/bin"
                "USER=${oci.user}"
              ];
            };
          };
      };
    };
}
