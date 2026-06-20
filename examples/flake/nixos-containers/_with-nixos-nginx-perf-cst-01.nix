# Example: Nginx with performance tuning (mimalloc + glibc tunables)
#
# Demonstrates container performance optimization using nix-oci's
# performance module. The allocator is injected via LD_PRELOAD at
# build time -- zero application changes required.
#
# What this shows:
# - Alternative allocator injection (mimalloc via LD_PRELOAD)
# - glibc malloc tunable configuration (arena_max, mmap_threshold)
# - Performance options combined with a standard NixOS service
# - OCI labels encoding performance hints
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxPerf = {
            mainService = "nginx";
            nixosConfig.modules = [
                (
                  { ... }:
                  {
                    services.nginx = {
                      enable = true;
                      virtualHosts."localhost" = {
                        root = "/var/www";
                        locations."/".extraConfig = ''
                          return 200 "Hello from nix-oci perf!";
                          default_type text/plain;
                        '';
                      };
                    };
                  }
                )
              ];
            isRoot = true;
            performance = {
              enable = true;
              allocator = "mimalloc";
              glibcTunables = {
                "glibc.malloc.arena_max" = "2";
                "glibc.malloc.mmap_threshold" = "131072";
              };
            };
            labels = {
              "org.opencontainers.image.title" = "nginx-perf-tuned";
              "org.opencontainers.image.description" =
                "Nginx with mimalloc allocator and glibc tunable optimization";
            };
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-perf-cst.yaml
              ];
            };
          };
        };
      };
  };
}
