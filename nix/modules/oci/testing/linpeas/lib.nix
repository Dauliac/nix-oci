# Privilege escalation auditing functions (linPEAS)
#
# Uses mkContainerProbe with needsShell=true — busybox is injected
# automatically as the shell interpreter.
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
        mkScriptLinpeas = {
          type = types.functionTo types.package;
          description = "Generate linPEAS privilege escalation auditing script";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkContainerProbe {
              name = "linpeas-${containerId}";
              inherit oci;
              probe = "${perSystemConfig.packages.linpeas}/bin/linpeas.sh";
              needsShell = true;
              args = "-q -s -N";
              failPatterns = [
                {
                  pattern = "docker.sock\\|docker\\.socket";
                  message = "Docker socket accessible inside container";
                }
              ];
              warnPatterns = [
                {
                  pattern = "You are root";
                  message = "Container process runs as root";
                }
              ];
            };
        };

        mkAppLinpeas = {
          type = types.functionTo types.attrs;
          description = "Create flake app for linPEAS privilege escalation auditing";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptLinpeas {
                  inherit perSystemConfig containerId;
                }
              }/bin/linpeas-${containerId}";
            };
        };

        mkCheckLinpeas = {
          type = types.functionTo types.package;
          description = "Run linPEAS as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkHermeticContainerProbe {
              name = "linpeas-${containerId}";
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
              probe = "${perSystemConfig.packages.linpeas}/bin/linpeas.sh";
              needsShell = true;
              args = "-q -s -N";
              failPatterns = [
                {
                  pattern = "docker.sock\\|docker\\.socket";
                  message = "Docker socket accessible";
                }
              ];
            };
        };
      };
    };
}
