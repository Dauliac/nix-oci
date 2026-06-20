# Container introspection functions (amicontained)
#
# Uses mkContainerProbe — static binary, no shell needed.
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
        mkScriptAmicontained = {
          type = types.functionTo types.package;
          description = "Generate amicontained container introspection script";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkContainerProbe {
              name = "amicontained-${containerId}";
              inherit oci;
              probe = "${perSystemConfig.packages.amicontained}/bin/amicontained";
              failPatterns = [
                {
                  pattern = "Is Privileged.*true";
                  message = "Container is running in privileged mode";
                }
              ];
              warnPatterns = [
                {
                  pattern = "Seccomp.*disabled";
                  message = "Seccomp is disabled — no syscall filtering";
                }
              ];
            };
        };

        mkAppAmicontained = {
          type = types.functionTo types.attrs;
          description = "Create flake app for amicontained container introspection";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptAmicontained {
                  inherit perSystemConfig containerId;
                }
              }/bin/amicontained-${containerId}";
            };
        };

        mkCheckAmicontained = {
          type = types.functionTo types.package;
          description = "Run amicontained as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkHermeticContainerProbe {
              name = "amicontained-${containerId}";
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
              probe = "${perSystemConfig.packages.amicontained}/bin/amicontained";
              failPatterns = [
                {
                  pattern = "Is Privileged.*true";
                  message = "Container is running in privileged mode";
                }
              ];
            };
        };
      };
    };
}
