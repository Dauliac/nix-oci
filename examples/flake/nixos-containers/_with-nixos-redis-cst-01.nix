# Example: NixOS Redis container with container-structure-test
#
# Demonstrates a Redis container built via NixOS modules.
# Redis runs in foreground by default in NixOS (daemonize no),
# so no service adapter is needed.
#
# Note: NixOS redis uses services.redis.servers.<name>, creating a
# systemd service "redis-<name>". Since config.services.redis-default
# doesn't exist as an attribute path, package must be set explicitly.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          nixosRedisCst = {
            mainService = "redis-default";
            nixosConfig.modules = [
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
            package = pkgs.redis;
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
