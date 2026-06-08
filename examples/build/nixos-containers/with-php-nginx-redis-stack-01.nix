# Example: PHP + nginx + Redis multi-container stack
#
# Demonstrates building tightly coupled containers with MAXIMUM shared
# configuration. All three containers derive ports, labels, and app paths
# from a single source of truth.
#
# Architecture:
#   [client] → [nginx:8080] → (FastCGI) → [php-fpm:9000] → [redis:6379]
#
# Shared config pattern:
#   - Ports, container names, labels defined ONCE in `let` block
#   - PHP app package referenced by BOTH nginx and php-fpm containers
#   - nginx config auto-generated from shared port/path variables
#   - All three get auto-derived healthchecks from service adapters
#
# Healthchecks (all automatic, zero user config):
#   - nginx: stub_status on 127.0.0.1:10246 (injected)
#   - php-fpm: cgi-fcgi ping via /ping (injected)
#   - redis: redis-cli ping
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      let
        # ──────────────────────────────────────────────────────
        # SHARED CONFIGURATION — single source of truth
        # ──────────────────────────────────────────────────────
        # Project identity
        project = "myapp";
        team = "backend";

        # Network topology — change here, flows everywhere
        phpFpmPort = 9000;
        redisPort = 6379;
        httpPort = 8080;

        # Container naming — consistent prefix
        containerName = suffix: "${project}-${suffix}";

        # Shared labels applied to ALL containers in the stack
        commonLabels = {
          "com.example.project" = project;
          "com.example.team" = team;
          "com.example.stack" = "php-nginx-redis";
        };

        # ──────────────────────────────────────────────────────
        # PHP APPLICATION — shared between nginx and php-fpm
        # ──────────────────────────────────────────────────────

        documentRoot = "/var/www/${project}/public";

        phpApp = pkgs.writeTextDir "var/www/${project}/public/index.php" ''
          <?php
          // Redis connection using shared port
          $redis = new Redis();
          $connected = @$redis->connect('${containerName "redis"}', ${toString redisPort});

          header('Content-Type: application/json');
          echo json_encode([
              'app' => '${project}',
              'php' => PHP_VERSION,
              'redis' => $connected ? $redis->ping() : 'disconnected',
              'hostname' => gethostname(),
              'timestamp' => date('c'),
          ]);
        '';

        # Static assets served directly by nginx
        staticAssets = pkgs.writeTextDir "var/www/${project}/public/health.json" ''
          {"status":"healthy","service":"${project}"}
        '';

        # ──────────────────────────────────────────────────────
        # NGINX CONFIG — generated from shared variables
        # ──────────────────────────────────────────────────────

        # nginx config references php-fpm via the shared port.
        # In production, "php-fpm" would resolve via container networking
        # (Docker network, K8s service, etc.). For build-time validation,
        # the config is syntactically complete.
        nginxFastcgiConfig = ''
          fastcgi_pass 127.0.0.1:${toString phpFpmPort};
          fastcgi_param SCRIPT_FILENAME ${documentRoot}$fastcgi_script_name;
          include ${pkgs.nginx}/conf/fastcgi_params;
          fastcgi_param SERVER_NAME $host;
        '';
      in
      {
        config.oci.containers = {
          # ──────────────────────────────────────────────
          # CONTAINER 1: nginx — reverse proxy + static files
          # ──────────────────────────────────────────────
          "${containerName "nginx"}" = {
            nixosConfig = {
              enable = true;
              mainService = "nginx";
              modules = [
                (
                  { ... }:
                  {
                    services.nginx = {
                      enable = true;
                      virtualHosts."localhost" = {
                        listen = [
                          {
                            addr = "0.0.0.0";
                            port = httpPort;
                          }
                        ];
                        root = documentRoot;

                        # Static files — served directly by nginx
                        locations."/".tryFiles = "$uri $uri/ /index.php$is_args$args";

                        # PHP files — forwarded to FPM container
                        locations."~ \\.php$".extraConfig = nginxFastcgiConfig;

                        # Health endpoint for external probes
                        # (adapter also injects stub_status for internal health)
                        locations."/health.json" = {
                          root = documentRoot;
                        };
                      };
                    };
                  }
                )
              ];
            };
            isRoot = true;
            ports = [ "${toString httpPort}:${toString httpPort}" ];
            dependencies = [
              phpApp
              staticAssets
            ];
            labels = commonLabels // {
              "com.example.role" = "reverse-proxy";
            };
          };

          # ──────────────────────────────────────────────
          # CONTAINER 2: PHP-FPM — application runtime
          # ──────────────────────────────────────────────
          "${containerName "php"}" = {
            nixosConfig = {
              enable = true;
              mainService = "phpfpm-${project}";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.phpfpm.pools.${project} = {
                      user = "app";
                      group = "app";
                      settings = {
                        "listen" = "0.0.0.0:${toString phpFpmPort}";
                        "pm" = "dynamic";
                        "pm.max_children" = 10;
                        "pm.start_servers" = 2;
                        "pm.min_spare_servers" = 1;
                        "pm.max_spare_servers" = 4;
                        "pm.max_requests" = 500;
                      };
                      phpEnv = {
                        REDIS_HOST = containerName "redis";
                        REDIS_PORT = toString redisPort;
                        APP_NAME = project;
                      };
                      phpPackage = pkgs.php.withExtensions (
                        {
                          enabled,
                          all,
                        }:
                        enabled
                        ++ [
                          all.redis
                          all.opcache
                        ]
                      );
                    };

                    users.users.app = {
                      isSystemUser = true;
                      group = "app";
                    };
                    users.groups.app = { };
                  }
                )
              ];
            };
            ports = [ "${toString phpFpmPort}:${toString phpFpmPort}" ];
            dependencies = [ phpApp ];
            labels = commonLabels // {
              "com.example.role" = "application";
            };
            # Healthcheck auto-derived: cgi-fcgi ping to /ping
            # StopSignal auto-derived: SIGQUIT
          };

          # ──────────────────────────────────────────────
          # CONTAINER 3: Redis — session cache
          # ──────────────────────────────────────────────
          "${containerName "redis"}" = {
            nixosConfig = {
              enable = true;
              mainService = "redis-${project}";
              modules = [
                (
                  { ... }:
                  {
                    services.redis.servers.${project} = {
                      enable = true;
                      bind = "0.0.0.0";
                      port = redisPort;
                      settings = {
                        maxmemory = "64mb";
                        maxmemory-policy = "allkeys-lru";
                        save = "";
                      };
                    };
                  }
                )
              ];
            };
            package = pkgs.redis;
            ports = [ "${toString redisPort}:${toString redisPort}" ];
            labels = commonLabels // {
              "com.example.role" = "cache";
            };
            # Healthcheck auto-derived: redis-cli ping
            # StopSignal auto-derived: SIGTERM
          };
        };
      };
  };
}
