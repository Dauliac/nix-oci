# nix-lib: generate OCI labels for performance configuration.
#
# Produces labels under the io.github.dauliac.nix-oci.performance.* namespace.
# Called by mkAutoLabels or image builders when performance is enabled.
{ lib, ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkPerformanceLabels = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Generate OCI labels encoding performance tuning hints.";
        fn =
          { performance }:
          let
            ns = "io.github.dauliac.nix-oci";
            cfg = performance;
          in
          lib.optionalAttrs (cfg.enable or false) (
            {
              "${ns}.performance.enabled" = "true";
            }
            // lib.optionalAttrs ((cfg.allocator or null) != null) {
              "${ns}.performance.allocator" = cfg.allocator;
            }
            // lib.optionalAttrs ((cfg.glibcTunables or { }) != { }) {
              "${ns}.performance.glibc-tunables" = "true";
            }
            // lib.optionalAttrs ((cfg.compression or "gzip") != "gzip") {
              "${ns}.performance.compression" = cfg.compression;
            }
            // lib.optionalAttrs (cfg.hwcaps.enable or false) {
              "${ns}.performance.hwcaps-levels" = lib.concatStringsSep "," (cfg.hwcaps.levels or [ ]);
            }
            // lib.optionalAttrs ((cfg.march or null) != null) {
              "${ns}.performance.march" = cfg.march;
            }
          );
      };
    };
}
