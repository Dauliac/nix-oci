# Example: Nginx with custom-compiled modules (brotli, VTS metrics, more-headers)
#
# Demonstrates the killer feature of nix-oci + NixOS eval: custom-compiling
# nginx with additional modules is a single `services.nginx.package` override.
# No multi-stage Dockerfile, no manual C compilation -- just Nix.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxCustomModules = {
            mainService = "nginx";
            isRoot = true;
            nixosConfig.modules = [
              (
                { pkgs, ... }:
                {
                  services.nginx = {
                    enable = true;

                    # Custom nginx with compiled-in modules
                    package = pkgs.nginx.override {
                      modules = with pkgs.nginxModules; [
                        brotli
                        vts
                        moreheaders
                      ];
                    };

                    recommendedGzipSettings = true;
                    recommendedOptimisation = true;
                    recommendedProxySettings = true;

                    commonHttpConfig = ''
                      brotli on;
                      brotli_comp_level 6;
                      brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
                      vhost_traffic_status_zone;
                    '';

                    virtualHosts."localhost" = {
                      root = "/var/www";

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

                      locations."/metrics" = {
                        extraConfig = ''
                          vhost_traffic_status_display;
                          vhost_traffic_status_display_format json;
                        '';
                      };

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
