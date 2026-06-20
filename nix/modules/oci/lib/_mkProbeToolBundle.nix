# Pure factory function for container probe tool triplets.
#
# NOT a nix-lib module — imported directly by probe tool lib files.
# Must not be auto-discovered by import-tree (hence _ prefix).
#
# Accepts { lib, ociLib } and returns a function that generates
# mkScript/mkApp/mkCheck nix-lib entries from a tool specification.
{ lib }:
{
  toolId,
  file,
  description,
  probePath,
  needsShell ? false,
  args ? "",
  failPatterns ? [ ],
  warnPatterns ? [ ],
  hermeticFailPatterns ? null,
}:
let
  effectiveHermeticFailPatterns =
    if hermeticFailPatterns != null then hermeticFailPatterns else failPatterns;
in
# Returns a function: ociLib -> attrset of nix-lib entries.
# The ociLib is resolved lazily (only forced when fn bodies are called).
ociLib: {
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
        inherit
          oci
          needsShell
          args
          failPatterns
          warnPatterns
          ;
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
            inherit
              needsShell
              args
              failPatterns
              warnPatterns
              ;
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
}
