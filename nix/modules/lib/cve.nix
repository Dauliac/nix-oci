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
    mkScriptCVETrivy = mkOption {
      description = "To build trivy app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          config,
          perSystemConfig,
          containerId,
          pkgs,
        }:
        let
          oci = args.perSystemConfig.internal.OCIs.${containerId};
          containerConfig = args.perSystemConfig.containers.${containerId}.cve.trivy;
          archive = cfg.mkDockerArchive {
            inherit (args) pkgs;
            inherit oci;
            inherit (perSystemConfig.packages) skopeo;
          };
          ignoreFileFlag =
            if containerConfig.ignore.fileEnabled then "--ignorefile ${containerConfig.ignore.path}" else "";
          extraIgnoreFile = pkgs.writeText "extra-ignore.ignore" ''
            ${lib.concatMapStrings (ignore: "${ignore}\n") args.config.trivy.ignore.extra}
          '';
          extraIgnoreFileFlag =
            if (lib.length config.cve.trivy.ignore.extra) > 0 then "--ignorefile ${extraIgnoreFile}" else "";
          containerExtraIgnoreFile = pkgs.writeText "container-extra-ignore.ignore" ''
            ${lib.concatMapStrings (ignore: "${ignore}\n") containerConfig.ignore.extra}
          '';
          containerExtraIgnoreFileFlag =
            if (lib.length containerConfig.ignore.extra) > 0 then
              "--ignorefile ${containerExtraIgnoreFile}"
            else
              "";
        in
        args.pkgs.writeShellScriptBin "trivy" ''
          set -o errexit
          set -o pipefail
          set -o nounset
          ${args.perSystemConfig.packages.trivy}/bin/trivy image \
            --input ${archive} \
            ${ignoreFileFlag} \
            ${extraIgnoreFileFlag} \
            ${containerExtraIgnoreFileFlag} \
            --exit-code 1 \
            --scanners vuln
        '';
    };
    mkAppCVETrivy = mkOption {
      description = "To build trivy app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default = args: {
        type = "app";
        program = cfg.mkScriptCVETrivy args;
      };
    };
    mkScriptCVEGrype = mkOption {
      description = "To build grype app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        let
          oci = args.perSystemConfig.internal.OCIs.${containerId};
          containerConfig = args.perSystemConfig.containers.${containerId}.cve.grype;
          archive = cfg.mkDockerArchive {
            inherit (args) pkgs;
            inherit oci;
            inherit (perSystemConfig.packages) skopeo;
          };
          configFlag =
            if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
        in
        args.pkgs.writeShellScriptBin "grype" ''
          set -o errexit
          set -o pipefail
          set -o nounset
          ${args.perSystemConfig.packages.grype}/bin/grype \
            ${configFlag} \
            ${archive}
        '';
    };
    mkAppCVEGrype = mkOption {
      description = "To build grype app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        {
          type = "app";
          program = cfg.mkScriptCVEGrype args;
        };
    };
  };
}
