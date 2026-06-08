# Flake outputs for cross-build multi-arch OCI images
# Only contributes on Linux (OCI containers are Linux-only).
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
        packages = config.oci.internal.prefixedMultiArchOCILayouts;
        apps = config.oci.internal.prefixedPushMultiArchLayoutApps;
      };
}
