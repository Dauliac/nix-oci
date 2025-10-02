{
  lib,
  config,
  ...
}:
let
  cfg = config.oci.lib;
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.lib = {
    mkScriptSBOMSyft = mkOption {
      description = "To build syft app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        let
          oci = args.perSystemConfig.internal.OCIs.${containerId};
          containerConfig = args.perSystemConfig.containers.${containerId}.sbom.syft;
          archive = cfg.mkDockerArchive {
            inherit (args) pkgs;
            inherit oci;
            inherit (perSystemConfig.packages) skopeo;
          };
          configFlag =
            if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
        in
        args.pkgs.writeShellScriptBin "syft" ''
          set -o errexit
          set -o pipefail
          set -o nounset
          ${args.perSystemConfig.packages.syft}/bin/syft \
            ${configFlag} \
            ${archive}
        '';
    };
    mkAppSBOMSyft = mkOption {
      description = "To build syft app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        {
          type = "app";
          program = cfg.mkScriptSBOMSyft args;
        };
    };
  };
}
