# Dgoss testing functions
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
        mkScriptDgoss = {
          type = types.functionTo types.package;
          description = "Generate dgoss testing script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.test.dgoss;
            in
            pkgs.writeShellScriptBin "dgoss-${containerId}" ''
              set -o errexit
              set -o nounset
              set -o pipefail

              main() {
                ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon
                export GOSS_FILE=${containerConfig.optionsPath}
                ${perSystemConfig.packages.dgoss}/bin/dgoss \
                   run --entrypoint "" \
                  ${oci.imageName}:${oci.imageTag} \
                  kubectl version
              }
              main "$@"
            '';
        };

        mkAppDgoss = {
          type = types.functionTo types.attrs;
          description = "Create flake app for dgoss testing";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptDgoss {
                  inherit perSystemConfig containerId;
                }
              }/bin/dgoss-${containerId}";
            };
        };
      };
    };
}
