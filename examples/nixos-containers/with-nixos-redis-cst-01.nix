# Example: NixOS Redis container with container-structure-test
#
# Demonstrates a Redis container built via NixOS modules.
# Redis runs in foreground by default in NixOS (daemonize no),
# so no service adapter is needed.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosRedisCst = {
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
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./redis-cst.yaml
              ];
            };
          };
        };
      };
  };
}
