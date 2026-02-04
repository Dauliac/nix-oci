# Credentials leak detection functions (Trivy)
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
        mkScriptCredentialsLeakTrivy = {
          type = types.functionTo types.package;
          description = "Generate Trivy credentials leak detection script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
            in
            pkgs.writeShellScriptBin "credentials-leak-trivy-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              ${perSystemConfig.packages.trivy}/bin/trivy fs --scanners secret ${archive}
            '';
        };

        mkAppCredentialsLeakTrivy = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Trivy credentials leak detection";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptCredentialsLeakTrivy {
                  inherit perSystemConfig containerId;
                }
              }/bin/credentials-leak-trivy-${containerId}";
            };
        };
      };
    };
}
