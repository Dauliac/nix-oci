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
            };
            dependencies = [
              pkgs.curl
              pkgs.jq
            ];
            isRoot = true;
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
