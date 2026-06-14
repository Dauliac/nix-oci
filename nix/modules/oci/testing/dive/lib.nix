# Dive image analysis functions
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
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
      nix-lib.lib.oci = {
        mkCheckDive = {
          type = types.functionTo types.package;
          description = "Create dive analysis check for container image";
          file = "nix/modules/oci/testing/dive/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            pkgs.runCommandLocal "dive-${containerId}"
              {
                nativeBuildInputs = [
                  perSystemConfig.packages.dive
                  perSystemConfig.packages.skopeo
                  pkgs.gnutar
                  pkgs.python3
                ];
                meta.description = "Run dive on built image.";
              }
              ''
                ${ociLib.mkTransientArchive {
                  inherit oci;
                  skopeo = perSystemConfig.packages.skopeo;
                }}
                ${perSystemConfig.packages.dive}/bin/dive --source docker-archive --ci archive.tar
                touch $out
              '';
        };
      };
    };
}
