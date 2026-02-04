# SBOM generation functions (Syft)
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
        mkScriptSBOMSyft = {
          type = types.functionTo types.package;
          description = "Generate Syft SBOM generation script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.sbom.syft;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              configFlag =
                if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
            in
            pkgs.writeShellScriptBin "sbom-syft-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              ${perSystemConfig.packages.syft}/bin/syft ${configFlag} ${archive}
            '';
        };

        mkAppSBOMSyft = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Syft SBOM generation";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptSBOMSyft {
                  inherit perSystemConfig containerId;
                }
              }/bin/sbom-syft-${containerId}";
            };
        };
      };
    };
}
