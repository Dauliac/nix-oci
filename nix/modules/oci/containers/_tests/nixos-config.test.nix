# BDD test specs for nixosConfig (NixOS-OCI containers).
#
# Tests that containers built via NixOS module evaluation actually work
# at runtime — the entrypoint wrapper starts the service, the service
# responds, and NixOS-generated config files are correct.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.nixos-config = {
        eval-nginx = {
          given = "a container with nginx as NixOS mainService";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            nixosConfig = {
              mainService = "nginx";
              modules = [
                (
                  { ... }:
                  {
                    services.nginx = {
                      enable = true;
                      virtualHosts."localhost" = {
                        root = "/var/www";
                        locations."/".extraConfig = ''
                          return 200 "ok";
                          default_type text/plain;
                        '';
                      };
                    };
                  }
                )
              ];
            };
          };
        };

        deploy-nginx-serves-http = {
          given = "a NixOS container with nginx serving a static response";
          "when" = "the container is deployed and HTTP is requested";
          "then" = "nginx responds with the configured content";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8080:8080" ];
            nixosConfig = {
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
                            port = 8080;
                          }
                        ];
                        root = "/var/www";
                        locations."/health".extraConfig = ''
                          return 200 "nix-oci-nginx-ok";
                          default_type text/plain;
                        '';
                      };
                    };
                  }
                )
              ];
            };
          };
          assertions.httpResponds = {
            port = 8080;
            path = "/health";
            contains = "nix-oci-nginx-ok";
          };
        };

        # TODO: PostgreSQL deploy test needs writable volume for initdb.
        # The container crash-loops because /var/lib/postgresql is read-only.
        # Add once volume mounting is supported in BDD deploy specs.
      };
    };
}
