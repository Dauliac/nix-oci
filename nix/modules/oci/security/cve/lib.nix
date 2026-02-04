# CVE scanning functions (Trivy, Grype)
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config;
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
        mkScriptCVETrivy = {
          type = types.functionTo types.package;
          description = "Generate Trivy CVE scanning script";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.cve.trivy;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              ignoreFileFlag =
                if containerConfig.ignore.fileEnabled then "--ignorefile ${containerConfig.ignore.path}" else "";
              extraIgnoreFile = pkgs.writeText "extra-ignore.ignore" ''
                ${lib.concatMapStrings (ignore: "${ignore}\n") (globalConfig.cve.trivy.ignore.extra or [ ])}
              '';
              extraIgnoreFileFlag =
                if (lib.length (globalConfig.cve.trivy.ignore.extra or [ ])) > 0 then
                  "--ignorefile ${extraIgnoreFile}"
                else
                  "";
              containerExtraIgnoreFile = pkgs.writeText "container-extra-ignore.ignore" ''
                ${lib.concatMapStrings (ignore: "${ignore}\n") containerConfig.ignore.extra}
              '';
              containerExtraIgnoreFileFlag =
                if (lib.length containerConfig.ignore.extra) > 0 then
                  "--ignorefile ${containerExtraIgnoreFile}"
                else
                  "";
            in
            pkgs.writeShellScriptBin "trivy-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              ${perSystemConfig.packages.trivy}/bin/trivy image \
                --input ${archive} \
                ${ignoreFileFlag} \
                ${extraIgnoreFileFlag} \
                ${containerExtraIgnoreFileFlag} \
                --exit-code 1 \
                --scanners vuln
            '';
        };

        mkAppCVETrivy = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Trivy CVE scanning";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptCVETrivy {
                  inherit perSystemConfig containerId globalConfig;
                }
              }/bin/trivy-${containerId}";
            };
        };

        mkScriptCVEGrype = {
          type = types.functionTo types.package;
          description = "Generate Grype CVE scanning script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.cve.grype;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              configFlag =
                if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
            in
            pkgs.writeShellScriptBin "grype-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              ${perSystemConfig.packages.grype}/bin/grype \
                ${configFlag} \
                ${archive}
            '';
        };

        mkAppCVEGrype = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Grype CVE scanning";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptCVEGrype {
                  inherit perSystemConfig containerId;
                }
              }/bin/grype-${containerId}";
            };
        };
      };
    };
}
