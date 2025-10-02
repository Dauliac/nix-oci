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
  options.lib = {
    mkScriptDgoss = mkOption {
      description = "A function to create a check that runs dgoss on a built image using podman.";
      type = types.functionTo types.package;
      default =
        {
          pkgs,
          perSystemConfig,
          containerId,
        }:
        let
          name = "dgoss";
          oci = perSystemConfig.internal.OCIs.${containerId};
        in
        # TODO: we need to add debug deps or to pass the command to run as an dgoss option
        pkgs.writeShellScriptBin name ''
          set -o errexit
          set -o nounset
          set -o pipefail

          main() {
            ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon
            export GOSS_FILE=${perSystemConfig.containers.${containerId}.test.${name}.optionsPath}
            ${perSystemConfig.packages.${name}}/bin/${name} \
               run --entrypoint "" \
              ${oci.imageName}:${oci.imageTag} \
              kubectl version
          }
          main "$@"
        '';
    };
    mkAppDgoss = mkOption {
      description = "";
      type = types.functionTo types.attrs;
      default = args: {
        type = "app";
        program = cfg.mkScriptDgoss args;
      };
    };
  };
}
