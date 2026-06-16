# Dive image analysis functions
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  {
    mkCheckDive = {
      type = lib.types.functionTo lib.types.package;
      description = "Create dive analysis check for container image";
      file = "nix/modules/oci/_testing/dive/lib.nix";
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
        in
        ociLib.mkArchiveScanCheck {
          name = "dive-${containerId}";
          metaDescription = "Run dive on built image.";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          toolPackages = [ perSystemConfig.packages.dive ];
          checkCommand = ''
            ${perSystemConfig.packages.dive}/bin/dive --source docker-archive --ci archive.tar
          '';
        };
    };
  }
)
