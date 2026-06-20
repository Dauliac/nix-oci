# Example: NixOS nginx container with extra dependencies and CST
#
# Demonstrates adding extra packages (curl, jq) to a NixOS-based
# container for debugging or health-check scripts.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          nixosNginxDeps = {
            mainService = "nginx";
            nixosConfig.modules = [
                (
                  { ... }:
                  {
                    services.nginx = {
                      enable = true;
                      virtualHosts."localhost" = {
                        root = "/var/www";
                        locations."/" = {
                          extraConfig = ''
                            return 200 "ok";
                            default_type text/plain;
                          '';
                        };
                        locations."/health" = {
                          extraConfig = ''
                            return 200 '{"status":"healthy"}';
                            default_type application/json;
                          '';
                        };
                      };
                    };
                  }
                )
              ];
            # nginx needs root to bind port 80
            isRoot = true;
            dependencies = [
              pkgs.curl
              pkgs.jq
            ];
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-deps-cst.yaml
              ];
            };
          };
        };
      };
  };
}
