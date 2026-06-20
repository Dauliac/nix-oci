# Example: Nginx as API gateway with rate limiting and custom error pages
#
# Demonstrates a production-grade reverse proxy pattern using NixOS module
# composition. The entire gateway config -- rate limiting, upstream backends,
# security headers, custom error pages -- is expressed as NixOS options.
#
# What this shows:
# - Rate limiting via nginx limit_req zones
# - Upstream backend configuration
# - Custom error pages injected via environment.etc
# - Security headers and CORS configuration
# - Multiple location blocks with different proxy targets
# - Access logging in JSON format for log aggregation
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxReverseProxy = {
            nixosConfig = {
              mainService = "nginx";
              modules = [
                (
                  { pkgs, ... }:
                  let
                    # Custom error pages built as a Nix derivation
                    errorPages = pkgs.runCommand "error-pages" { } ''
                      mkdir -p $out/var/www/errors
                      cat > $out/var/www/errors/404.html <<'HTML'
                      <!DOCTYPE html>
                      <html><head><title>404</title></head>
                      <body><h1>Not Found</h1><p>The requested resource does not exist.</p></body></html>
                      HTML
                      cat > $out/var/www/errors/502.html <<'HTML'
                      <!DOCTYPE html>
                      <html><head><title>502</title></head>
                      <body><h1>Bad Gateway</h1><p>The upstream server is unavailable.</p></body></html>
                      HTML
                      cat > $out/var/www/errors/503.html <<'HTML'
                      <!DOCTYPE html>
                      <html><head><title>503</title></head>
                      <body><h1>Service Unavailable</h1><p>Please try again later.</p></body></html>
                      HTML
                      cat > $out/var/www/errors/429.html <<'HTML'
                      <!DOCTYPE html>
                      <html><head><title>429</title></head>
                      <body><h1>Too Many Requests</h1><p>Rate limit exceeded. Please slow down.</p></body></html>
                      HTML
                    '';
                  in
                  {
                    services.nginx = {
                      enable = true;

                      recommendedGzipSettings = true;
                      recommendedOptimisation = true;
                      recommendedProxySettings = true;
                      recommendedTlsSettings = true;

                      # Rate limiting and logging config
                      commonHttpConfig = ''
                        # Rate limiting zones
                        limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
                        limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

                        # JSON access log for log aggregation (ELK, Loki, etc.)
                        log_format json_combined escape=json
                          '{'
                            '"time_local":"$time_local",'
                            '"remote_addr":"$remote_addr",'
                            '"request":"$request",'
                            '"status": "$status",'
                            '"body_bytes_sent":"$body_bytes_sent",'
                            '"request_time":"$request_time",'
                            '"upstream_response_time":"$upstream_response_time",'
                            '"http_user_agent":"$http_user_agent",'
                            '"http_x_forwarded_for":"$http_x_forwarded_for"'
                          '}';

                        # Upstream backend pools
                        upstream api_backend {
                          least_conn;
                          server 127.0.0.1:3000;
                          server 127.0.0.1:3001;
                          keepalive 32;
                        }

                        upstream auth_backend {
                          server 127.0.0.1:4000;
                          keepalive 8;
                        }
                      '';

                      virtualHosts."gateway" = {
                        default = true;
                        listen = [
                          {
                            addr = "0.0.0.0";
                            port = 8080;
                          }
                        ];

                        # Custom error pages
                        extraConfig = ''
                          error_page 404 /errors/404.html;
                          error_page 502 /errors/502.html;
                          error_page 503 /errors/503.html;
                          error_page 429 /errors/429.html;
                        '';

                        locations."/errors/" = {
                          alias = "/var/www/errors/";
                          extraConfig = "internal;";
                        };

                        # API endpoints with rate limiting
                        # Security headers are repeated in each location that uses
                        # add_header -- nginx drops parent add_header directives when
                        # a location defines its own (by design).
                        locations."/api/" = {
                          proxyPass = "http://api_backend";
                          extraConfig = ''
                            limit_req zone=api burst=20 nodelay;
                            limit_req_status 429;

                            # CORS + security headers
                            add_header Access-Control-Allow-Origin "*" always;
                            add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
                            add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
                            add_header X-Content-Type-Options "nosniff" always;
                            add_header X-Frame-Options "DENY" always;
                            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
                            add_header Referrer-Policy "strict-origin-when-cross-origin" always;
                            add_header Content-Security-Policy "default-src 'self'" always;

                            if ($request_method = OPTIONS) {
                              return 204;
                            }

                            proxy_http_version 1.1;
                            proxy_set_header Connection "";
                          '';
                        };

                        # Auth endpoint with stricter rate limiting
                        locations."/auth/" = {
                          proxyPass = "http://auth_backend";
                          extraConfig = ''
                            limit_req zone=login burst=5 nodelay;
                            limit_req_status 429;
                            proxy_http_version 1.1;
                            proxy_set_header Connection "";
                          '';
                        };

                        # Health endpoint (no rate limiting)
                        locations."/health" = {
                          extraConfig = ''
                            return 200 '{"status":"healthy","service":"gateway"}';
                            default_type application/json;
                          '';
                        };

                        # Metrics endpoint (restricted access in production)
                        locations."/nginx_status" = {
                          extraConfig = ''
                            stub_status;
                          '';
                        };
                      };
                    };

                    # Inject the error pages derivation into the root filesystem
                    environment.systemPackages = [ errorPages ];
                  }
                )
              ];
            };
            isRoot = true;
            ports = [ "8080:8080" ];
            environment = {
              GATEWAY_ENV = "production";
            };
            labels = {
              "org.opencontainers.image.title" = "nginx-api-gateway";
              "org.opencontainers.image.description" =
                "Nginx reverse proxy with rate limiting and custom error pages";
            };
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-reverse-proxy-cst.yaml
              ];
            };
          };
        };
      };
  };
}
