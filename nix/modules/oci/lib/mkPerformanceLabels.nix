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
        file = "nix/modules/oci/lib/mkPerformanceLabels.nix";
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
            // lib.optionalAttrs (cfg.turbo.enable or false) {
              "${ns}.performance.turbo" = "true";
            }
            // lib.optionalAttrs ((cfg.turbo.enable or false) && (cfg.turbo.soci or false)) {
              "${ns}.performance.turbo-soci" = "true";
            }
            // lib.optionalAttrs ((cfg.turbo.enable or false) && (cfg.turbo.layerCache or true)) {
              "${ns}.performance.turbo-layer-cache" = "true";
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
                turbo = {
                  enable = false;
                  soci = false;
                  layerCache = true;
                };
              };
            };
            assertions = [
              {
                name = "has enabled label";
                check = result: result."io.github.dauliac.nix-oci.performance.enabled" == "true";
              }
              {
                name = "has allocator label";
                check = result: result."io.github.dauliac.nix-oci.performance.allocator" == "mimalloc";
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
                turbo = {
                  enable = false;
                  soci = false;
                  layerCache = true;
                };
              };
            };
            expected = { };
          };
          "includes turbo and soci labels" = {
            args = {
              performance = {
                enable = true;
                allocator = null;
                glibcTunables = { };
                compression = "gzip";
                hwcaps.enable = false;
                march = null;
                turbo = {
                  enable = true;
                  soci = true;
                  layerCache = true;
                };
              };
            };
            assertions = [
              {
                name = "has turbo label";
                check = result: result."io.github.dauliac.nix-oci.performance.turbo" == "true";
              }
              {
                name = "has soci label";
                check = result: result."io.github.dauliac.nix-oci.performance.turbo-soci" == "true";
              }
              {
                name = "has layer-cache label";
                check = result: result."io.github.dauliac.nix-oci.performance.turbo-layer-cache" == "true";
              }
            ];
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
                turbo = {
                  enable = false;
                  soci = false;
                  layerCache = true;
                };
              };
            };
            assertions = [
              {
                name = "has compression label";
                check = result: result."io.github.dauliac.nix-oci.performance.compression" == "zstd";
              }
            ];
          };
        };
      };
    };
}
