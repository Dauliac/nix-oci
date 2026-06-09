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
        tests = {
          "generates labels with allocator" = {
            args = {
              performance = {
                enable = true;
                allocator = "mimalloc";
                glibcTunables = { };
                compression = "gzip";
                hwcaps.enable = false;
                march = null;
              };
            };
            assertions = [
              {
                name = "has enabled label";
                check =
                  result:
                  result."io.github.dauliac.nix-oci.performance.enabled" == "true";
              }
              {
                name = "has allocator label";
                check =
                  result:
                  result."io.github.dauliac.nix-oci.performance.allocator" == "mimalloc";
              }
            ];
          };
          "returns empty when disabled" = {
            args = {
              performance = {
                enable = false;
                allocator = null;
                glibcTunables = { };
                compression = "gzip";
                hwcaps.enable = false;
                march = null;
              };
            };
            expected = { };
          };
          "includes zstd compression label" = {
            args = {
              performance = {
                enable = true;
                allocator = null;
                glibcTunables = { };
                compression = "zstd";
                hwcaps.enable = false;
                march = null;
              };
            };
            assertions = [
              {
                name = "has compression label";
                check =
                  result:
                  result."io.github.dauliac.nix-oci.performance.compression" == "zstd";
              }
            ];
          };
        };
      };
    };
}
