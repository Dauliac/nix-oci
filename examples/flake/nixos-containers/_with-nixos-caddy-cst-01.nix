# Example: NixOS Caddy web server container with CST
#
# Caddy runs in foreground by default (no service adapter needed).
# Extra tools added via environment.systemPackages for health checks.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosCaddyCst = {
            mainService = "caddy";
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
                  {
                    services.caddy = {
                      enable = true;
                      virtualHosts."localhost:8080".extraConfig = ''
                        respond "Hello from Caddy in nix-oci!"
                      '';
                    };
                    environment.systemPackages = with pkgs; [
                      curl
                    ];
                  }
                )
              ];
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./caddy-cst.yaml
              ];
            };
          };
        };
      };
  };
}
