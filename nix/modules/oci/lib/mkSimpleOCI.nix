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
                null
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId globalConfig;
                };
            optimized = oci.optimizeLayers or false;
            rootDeps = if optimized then [ ] else oci.dependencies;
            depsLayers =
              if optimized && oci.dependencies != [ ] then
                [
                  (ociLib.mkDepsLayer {
                    inherit perSystemConfig;
                    dependencies = oci.dependencies;
                  })
                ]
              else
                [ ];
          in
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              copyToRoot = [
                (ociLib.mkRoot {
                  inherit (oci)
                    package
                    tag
                    user
                    ;
                  dependencies = rootDeps;
                })
                # Standard FHS temp directories
                (pkgs.runCommand "fhs-dirs" { } "mkdir -p $out/tmp $out/var/tmp")
              ]
              ++ (oci.configFiles or [ ]);
              config = {
                inherit (oci) entrypoint;
                User = oci.user;
                Env = [
                  "PATH=/bin"
                  "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                  "USER=${oci.user}"
                ];
              }
              // lib.optionalAttrs (oci.labels != { }) {
                Labels = oci.labels;
              };
            }
            // lib.optionalAttrs (fromImage != null) {
              inherit fromImage;
            }
            // lib.optionalAttrs optimized {
              layers = depsLayers;
              maxLayers = 40;
            }
          );
      };
    };
}
