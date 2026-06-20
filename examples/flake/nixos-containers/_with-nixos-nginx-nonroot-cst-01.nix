# Example: NixOS nginx container running as non-root with CST
#
# Demonstrates a non-root NixOS container. The user is auto-derived
# from the container name (truncated to 31 chars). NixOS modules
# create the user, group, and home directory.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxNonroot = {
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
                          return 200 "Hello from non-root nginx!";
                          default_type text/plain;
                        '';
                      };
                    };
                  }
                )
              ];
            };
            isRoot = false;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-nonroot-cst.yaml
              ];
            };
          };
        };
      };
  };
}
