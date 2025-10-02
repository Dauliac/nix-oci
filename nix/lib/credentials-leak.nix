{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  cfg = config.oci.lib;
in
{
  options.oci.lib = {
    mkScriptCredentialsLeakTrivy = mkOption {
      description = "To build trivy app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          archive = cfg.mkDockerArchive {
            inherit (args) pkgs;
            inherit oci;
            inherit (perSystemConfig.packages) skopeo;
          };
        in
        args.pkgs.writeShellScriptBin "trivy" ''
          set -o errexit
          set -o pipefail
          set -o nounset
          set -x
          ${args.perSystemConfig.packages.trivy}/bin/trivy image \
            --input ${archive} \
            --exit-code 1 \
            --scanners secret
        '';
    };
    mkAppCredentialsLeakTrivy = mkOption {
      description = "To build trivy app to check for CVEs on OCI.";
      type = types.functionTo types.attrs;
      default =
        args@{
          perSystemConfig,
          containerId,
          pkgs,
        }:
        {
          type = "app";
          program = cfg.mkScriptCredentialsLeakTrivy args;
        };
    };
  };
}
