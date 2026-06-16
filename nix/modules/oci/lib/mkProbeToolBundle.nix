# Factory: generate mkScript/mkApp/mkCheck triplet for container probe tools.
#
# Each probe tool (amicontained, cdk, deepce, linpeas) needs three functions:
#   - mkScript*  (non-hermetic, needs running podman daemon)
#   - mkApp*     (flake app wrapping mkScript)
#   - mkCheck*   (hermetic, runs inside nix sandbox via mkPodmanSandboxCheck)
#
# This factory generates all three from a single tool specification, eliminating
# duplicated probe/args/failPatterns/warnPatterns definitions.
{ ... }:
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
      nix-lib.lib.oci.mkProbeToolBundle = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Factory: create mkScript/mkApp/mkCheck functions for a container probe tool.

          Returns an attrset with three nix-lib entries: mkScript, mkApp, mkCheck.
          The probe, args, failPatterns, and warnPatterns are defined once and shared
          across all three functions.
        '';
        file = "nix/modules/oci/lib/mkProbeToolBundle.nix";
        fn =
          {
            # Tool identifier (e.g. "deepce", "amicontained")
            toolId,
            # Source file for nix-lib metadata
            file,
            # Human-readable description (e.g. "DEEPCE container escape detection")
            description,
            # Function: perSystemConfig -> path to probe binary/script
            probePath,
            # If true, inject busybox as /bin/sh for script execution
            needsShell ? false,
            # Arguments passed to the probe
            args ? "",
            # Grep patterns that cause hard failure. Each: { pattern; message; }
            failPatterns ? [ ],
            # Grep patterns that emit warnings. Each: { pattern; message; }
            warnPatterns ? [ ],
            # Subset of failPatterns for hermetic check (defaults to failPatterns)
            hermeticFailPatterns ? null,
          }:
          let
            effectiveHermeticFailPatterns =
              if hermeticFailPatterns != null then hermeticFailPatterns else failPatterns;
          in
          {
            mkScript = {
              type = lib.types.functionTo lib.types.package;
              description = "Generate ${description} script";
              inherit file;
              fn =
                {
                  perSystemConfig,
                  containerId,
                }:
                let
                  oci = perSystemConfig.internal.OCIs.${containerId};
                in
                ociLib.mkContainerProbe {
                  name = "${toolId}-${containerId}";
                  inherit oci needsShell args failPatterns warnPatterns;
                  probe = probePath perSystemConfig;
                };
            };

            mkApp = {
              type = lib.types.functionTo lib.types.attrs;
              description = "Create flake app for ${description}";
              inherit file;
              fn =
                {
                  perSystemConfig,
                  containerId,
                }:
                {
                  type = "app";
                  program = "${
                    ociLib.mkContainerProbe {
                      name = "${toolId}-${containerId}";
                      oci = perSystemConfig.internal.OCIs.${containerId};
                      inherit needsShell args failPatterns warnPatterns;
                      probe = probePath perSystemConfig;
                    }
                  }/bin/${toolId}-${containerId}";
                };
            };

            mkCheck = {
              type = lib.types.functionTo lib.types.package;
              description = "Run ${description} as a hermetic check via podman-in-sandbox";
              inherit file;
              fn =
                {
                  perSystemConfig,
                  containerId,
                }:
                let
                  oci = perSystemConfig.internal.OCIs.${containerId};
                in
                ociLib.mkHermeticContainerProbe {
                  name = "${toolId}-${containerId}";
                  dockerArchive = ociLib.mkDockerArchive {
                    inherit oci;
                    inherit (perSystemConfig.packages) skopeo;
                  };
                  imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
                  inherit needsShell args;
                  probe = probePath perSystemConfig;
                  failPatterns = effectiveHermeticFailPatterns;
                };
            };
          };
      };
    };
}
