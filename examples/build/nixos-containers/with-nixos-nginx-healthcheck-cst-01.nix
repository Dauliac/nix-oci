# Example: NixOS nginx container with auto-derived healthcheck + CST
#
# Demonstrates the healthcheck feature: the nginx service adapter
# auto-detects the /health location and builds a curl-based healthcheck
# that gets baked into the OCI image manifest. CST verifies the
# healthcheck tool (curl) is available in the image.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxHealthcheck = {
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
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-healthcheck-cst.yaml
              ];
            };
          };
        };
      };
  };
}
