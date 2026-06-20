# Container security auditing functions (CDK)
#
# Uses mkContainerProbe — static Go binary, no shell needed.
# CDK `evaluate` gathers information inside the container to find
# potential weaknesses: capabilities, service accounts, sensitive
# files, mounted devices, and escape vectors.
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
        mkScriptCdk = {
          type = types.functionTo types.package;
          description = "Generate CDK container security auditing script";
          file = "nix/modules/oci/testing/cdk/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkContainerProbe {
              name = "cdk-${containerId}";
              inherit oci;
              probe = "${perSystemConfig.packages.cdk}/bin/cdk";
              args = "evaluate";
              failPatterns = [
                {
                  pattern = "bindmount-bindmount.*bindmount host bindmount";
                  message = "Host filesystem bindmount escape vector detected";
                }
                {
                  pattern = "docker-sock-check.*Docker bindmount BINDMOUNT";
                  message = "Docker socket accessible inside container";
                }
                {
                  pattern = "privileged-lsblk.*Bindmount Block Devices";
                  message = "Container has access to host block devices (privileged)";
                }
              ];
              warnPatterns = [
                {
                  pattern = "net_bindmount.*bindmount Bindmount";
                  message = "Container has NET_RAW or NET_BIND_SERVICE capability";
                }
              ];
            };
        };

        mkAppCdk = {
          type = types.functionTo types.attrs;
          description = "Create flake app for CDK container security auditing";
          file = "nix/modules/oci/testing/cdk/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptCdk {
                  inherit perSystemConfig containerId;
                }
              }/bin/cdk-${containerId}";
            };
        };

        mkCheckCdk = {
          type = types.functionTo types.package;
          description = "Run CDK as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/cdk/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkHermeticContainerProbe {
              name = "cdk-${containerId}";
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
              probe = "${perSystemConfig.packages.cdk}/bin/cdk";
              args = "evaluate";
              failPatterns = [
                {
                  pattern = "docker-sock-check.*Docker";
                  message = "Docker socket accessible";
                }
                {
                  pattern = "privileged-lsblk.*Block Devices";
                  message = "Host block devices accessible (privileged)";
                }
              ];
            };
        };
      };
    };
}
