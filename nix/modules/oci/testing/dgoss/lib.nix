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
              # Check existence at eval-time: interpolating `${path}` in a
              # Nix string copies it to the store and fails eval if the file
              # is missing. When no goss.yaml ships with the project, emit a
              # no-op script instead of triggering a hard eval failure.
              hasGossFile = builtins.pathExists containerConfig.optionsPath;
            in
            if !hasGossFile then
              pkgs.writeShellScriptBin "dgoss-${containerId}" ''
                echo "[dgoss-${containerId}] no goss file configured (expected at ${toString containerConfig.optionsPath}); skipping" >&2
                exit 0
              ''
            else
              pkgs.writeShellScriptBin "dgoss-${containerId}" ''
                set -o errexit
                set -o nounset
                set -o pipefail

                main() {
                  ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon
                  export GOSS_FILE=${containerConfig.optionsPath}
                  ${perSystemConfig.packages.dgoss}/bin/dgoss \
                    run ${
                      lib.optionalString (containerConfig.command != "") ''--entrypoint "" ''
                    }${oci.imageName}:${oci.imageTag} ${containerConfig.command}
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

        mkCheckDgoss = {
          type = types.functionTo types.package;
          description = "Run dgoss as a hermetic check via podman-in-sandbox";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.test.dgoss;
              hasGossFile = builtins.pathExists containerConfig.optionsPath;
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              entrypointOverride = lib.optionalString (containerConfig.command != "") ''--entrypoint "" '';
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
            in
            if !hasGossFile then
              pkgs.runCommand "dgoss-${containerId}" { } ''
                echo "[dgoss-${containerId}] no goss file at ${toString containerConfig.optionsPath}; skipping" >&2
                mkdir -p $out && touch $out/passed
              ''
            else
              ociLib.mkPodmanSandboxCheck {
                name = "dgoss-${containerId}";
                inherit dockerArchive;
                inherit imageRef;
                extraBuildInputs = [ perSystemConfig.packages.dgoss ];
                testScript = ''
                  export GOSS_FILE=${containerConfig.optionsPath}
                  ${perSystemConfig.packages.dgoss}/bin/dgoss \
                    run ${entrypointOverride}${imageRef} ${containerConfig.command}
                '';
              };
        };
      };
    };
}
