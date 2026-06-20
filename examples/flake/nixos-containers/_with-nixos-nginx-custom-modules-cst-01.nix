# Example: Nginx with custom-compiled modules (brotli, VTS metrics, more-headers)
#
# Demonstrates the killer feature of nix-oci + NixOS eval: custom-compiling
# nginx with additional modules is a single `services.nginx.package` override.
# No multi-stage Dockerfile, no manual C compilation -- just Nix.
#
# What this shows:
# - Custom nginx package with brotli compression, VTS metrics, and more-headers
# - VTS /metrics endpoint for Prometheus scraping
# - Brotli compression alongside gzip
# - Security headers via moreheaders module
# - stub_status for basic monitoring
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxCustomModules = {
            mainService = "nginx";
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
                  {
                    services.nginx = {
                      enable = true;

                      # Custom nginx with compiled-in modules -- this is the magic.
                      # In a traditional Dockerfile you'd need a multi-stage build
                      # to compile these from source. Here it's one line.
                      package = pkgs.nginx.override {
                        modules = with pkgs.nginxModules; [
                          brotli
                          vts
                          moreheaders
                        ];

                      # Recommended defaults for production
                      recommendedGzipSettings = true;
                      recommendedOptimisation = true;
                      recommendedProxySettings = true;

                      # Brotli compression (requires brotli module)
                      commonHttpConfig = ''
                        brotli on;
                        brotli_comp_level 6;
                        brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;

                        # VTS shared memory zone
                        vhost_traffic_status_zone;
                      '';

                      virtualHosts."localhost" = {
                        root = "/var/www";

                        # Security headers via more-headers module
                        extraConfig = ''
                          more_set_headers "X-Content-Type-Options: nosniff";
                          more_set_headers "X-Frame-Options: DENY";
                          more_set_headers "X-XSS-Protection: 1; mode=block";
                          more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
                        '';

                        locations."/" = {
                          extraConfig = ''
                            return 200 "Hello from custom nginx!";
                            default_type text/plain;
                          '';
                        };

                        locations."/health" = {
                          extraConfig = ''
                            return 200 '{"status":"healthy"}';
                            default_type application/json;
                          '';
                        };

                        # VTS metrics endpoint for Prometheus
                        locations."/metrics" = {
                          extraConfig = ''
                            vhost_traffic_status_display;
                            vhost_traffic_status_display_format json;
                          '';
                        };

                        # Standard stub_status for basic monitoring
                        locations."/nginx_status" = {
                          extraConfig = ''
                            stub_status;
                          '';
                        };
                      };
                    };
                  }
                )
              ];
            };
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-custom-modules-cst.yaml
              ];
            };
          };
        };
      };
  };
}
