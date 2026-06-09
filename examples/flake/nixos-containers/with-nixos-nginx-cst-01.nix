# Example: NixOS nginx container with container-structure-test
#
# Validates the nginx container built via NixOS modules:
# - Config files are present
# - User/group setup is correct
# - Entrypoint binary exists
# - Environment variables are set
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxCst = {
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
                          return 200 "Hello from nix-oci CST!";
                          default_type text/plain;
                        '';
                      };
                    };
                  }
                )
              ];
            };
            # nginx needs root to bind port 80 and manage worker processes
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-cst.yaml
              ];
            };
          };
        };
      };
  };
}
