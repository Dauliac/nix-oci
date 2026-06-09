# Example: Redis with performance tuning (tcmalloc + glibc tunables)
#
# Demonstrates container performance optimization with tcmalloc -- Google's
# per-CPU-cache allocator that excels for high-concurrency servers like Redis.
#
# What this shows:
# - tcmalloc allocator injection via LD_PRELOAD
# - glibc tunable optimization for containerized workloads
# - Performance options combined with Redis NixOS service
# - zstd layer compression for faster image pulls
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosRedisPerf = {
            nixosConfig = {
              enable = true;
              mainService = "redis";
              modules = [
                (
                  { lib, ... }:
                  {
                    services.redis.servers.default = {
                      enable = true;
                      bind = "0.0.0.0";
                      port = 6379;
                      settings = {
                        maxmemory = "256mb";
                        maxmemory-policy = "allkeys-lru";
                      };
                    };
                  }
                )
              ];
            };
            isRoot = true;
            ports = [ "6379:6379" ];
            performance = {
              enable = true;
              allocator = "tcmalloc";
              glibcTunables = {
                "glibc.malloc.arena_max" = "2";
                "glibc.malloc.tcache_count" = "7";
              };
              compression = "zstd";
            };
            labels = {
              "org.opencontainers.image.title" = "redis-perf-tuned";
              "org.opencontainers.image.description" =
                "Redis with tcmalloc allocator and glibc tunable optimization";
            };
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./redis-perf-cst.yaml
              ];
            };
          };
        };
      };
  };
}
