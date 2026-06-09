# Example: NixOS deploy -- Redis container via nixosConfig.mainService.
#
# Demonstrates the converged build pipeline: the NixOS eval auto-derives
# entrypoint, healthcheck (redis-cli ping), stop signal (SIGTERM), and
# working directory from the Redis service adapter.
{ ... }:
{
  oci = {
    enable = true;
    backend = "podman";
    containers.redis = {
      nixosConfig = {
        mainService = "redis";
        modules = [
          {
            services.redis.servers.default = {
              enable = true;
              bind = "0.0.0.0";
              port = 6379;
            };
          }
        ];
      };
      autoStart = true;
      ports = [ "6379:6379" ];
    };
  };
}
