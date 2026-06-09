# Example: NixOS deploy -- multiple containers with dependencies.
#
# Shows deploying a web app + redis cache on the same NixOS host.
# Both containers auto-start, with proper port allocation.
{ pkgs, ... }:
{
  oci = {
    enable = true;
    backend = "podman";
    containers = {
      web = {
        package = pkgs.python3Minimal;
        dependencies = with pkgs; [
          bashInteractive
          coreutils
          curl
        ];
        entrypoint = [
          "${pkgs.writeShellScript "web" ''
            mkdir -p /tmp/www
            echo '{"status":"ok","cache":"redis://localhost:6379"}' > /tmp/www/health.json
            cd /tmp/www
            exec python3 -m http.server 8080
          ''}"
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
        package = pkgs.redis;
        entrypoint = [
          "${pkgs.redis}/bin/redis-server"
          "--bind"
          "0.0.0.0"
          "--port"
          "6379"
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
