# BDD test specs for NixOS Caddy service example.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.nixos-caddy = {
        deploy-caddy-serves-http = {
          given = "a NixOS container with Caddy serving a static response";
          "when" = "the container is deployed and HTTP is requested";
          "then" = "Caddy responds with the configured content";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "8081:8080" ];
            nixosConfig = {
              mainService = "caddy";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts."localhost:8080".extraConfig = ''
                        respond "nix-oci-caddy-ok"
                      '';
                    };
                    environment.systemPackages = [ pkgs.curl ];
                  }
                )
              ];
            };
          };
          assertions.httpResponds = {
            port = 8081;
            path = "/";
            contains = "nix-oci-caddy-ok";
          };
          exampleFile = ../../../../../../examples/flake/nixos-containers/with-nixos-caddy-cst-01.nix;
        };
      };
    };
}
