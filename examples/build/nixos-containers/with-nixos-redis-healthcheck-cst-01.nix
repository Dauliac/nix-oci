# Example: NixOS Redis container with auto-derived healthcheck + CST
#
# Demonstrates the healthcheck feature for Redis: the service adapter
# auto-derives `redis-cli -h 0.0.0.0 -p 6379 ping` from the NixOS
# module config. CST verifies redis-cli is available.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          nixosRedisHealthcheck = {
            nixosConfig = {
              enable = true;
              mainService = "redis-default";
              modules = [
                (
                  { ... }:
                  {
                    services.redis.servers.default = {
                      enable = true;
                      bind = "0.0.0.0";
                      port = 6379;
                    };
                  }
                )
              ];
            };
            package = pkgs.redis;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./redis-healthcheck-cst.yaml
              ];
            };
          };
        };
      };
  };
}
