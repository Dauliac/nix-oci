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
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
            in
            pkgs.runCommandLocal "dive-${containerId}"
              {
                buildInputs = [ perSystemConfig.packages.dive ];
                meta.description = "Run dive on built image.";
              }
              ''
                set -e
                ${perSystemConfig.packages.dive}/bin/dive --source docker-archive --ci ${dockerArchive}
                touch $out
              '';
        };
      };
    };
}
