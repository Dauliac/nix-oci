# Example: NixOS deploy -- multiple containers with dependencies.
#
# Shows deploying a web app + redis cache on the same NixOS host.
# Both containers auto-start, with proper port allocation.
# Redis uses nixosConfig.mainService to get auto-derived entrypoint,
# healthcheck, and stop signal from the NixOS service adapter.
{ pkgs, ... }:
let
  web = pkgs.writeShellApplication {
    name = "web";
    runtimeInputs = [ pkgs.python3Minimal ];
    text = ''
      cd /var/www
      exec python3 -m http.server 8080
    '';
  };
in
{
  oci = {
    enable = true;
    backend = "podman";
    containers = {
      web = {
        package = web;
        dependencies = [
          pkgs.curl
          (pkgs.writeTextDir "var/www/health.json" ''{"status":"ok","cache":"redis://localhost:6379"}'')
        ];
        autoStart = true;
        ports = [ "8080:8080" ];
        environment = {
          REDIS_HOST = "localhost";
          REDIS_PORT = "6379";
        };
        labels = {
          "app" = "web";
          "tier" = "frontend";
        };
      };

      redis = {
        mainService = "redis";
        nixosConfig.modules = [
          {
            services.redis.servers.default = {
              enable = true;
              bind = "0.0.0.0";
              port = 6379;
            };
          }
        ];
        autoStart = true;
        ports = [ "6379:6379" ];
        labels = {
          "app" = "redis";
          "tier" = "cache";
        };
      };
    };
  };
}
