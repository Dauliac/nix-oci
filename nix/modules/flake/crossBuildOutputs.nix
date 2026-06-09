# Flake outputs for cross-build and emulated-build multi-arch OCI images
# Only contributes on Linux (OCI containers are Linux-only).
# Cross-build and emulated-build are mutually exclusive per container,
# so output names never collide.
{ lib, ... }:
{
  config.perSystem =
    {
      config,
      system,
      ...
    }:
    lib.mkIf
      (builtins.elem system [
        "x86_64-linux"
        "aarch64-linux"
      ])
      {
        packages =
          config.oci.internal.prefixedMultiArchOCILayouts
          // config.oci.internal.prefixedEmulatedMultiArchOCILayouts;
        apps =
          config.oci.internal.prefixedPushMultiArchLayoutApps
          // config.oci.internal.prefixedPushEmulatedMultiArchLayoutApps;
      };
}
