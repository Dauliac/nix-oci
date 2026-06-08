# Container multiArch.crossBuild options
#
# When enabled, all target architectures are built locally (cross-compiled)
# and merged into a single OCI directory layout.
#
# Per-arch package overrides are now set via archConfigs (from perArch.nix):
#   oci.containers.myApp.archConfigs."aarch64-linux".package = crossPkg;
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.multiArch.crossBuild = {
            enable = mkOption {
              type = types.bool;
              description = ''
                Enable local cross-compilation for multi-arch images.

                When true, non-native architectures listed in `multiArch.systems`
                are cross-compiled on the current host and merged into a single
                OCI directory layout.

                Per-arch package overrides are set via `archConfigs`:
                  archConfigs."aarch64-linux".package = pkgs.pkgsCross.aarch64-multiplatform.hello;
              '';
              default = false;
            };
          };
        };
    };
}
