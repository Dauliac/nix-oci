# Example: NixOS nginx with extra packages via environment.systemPackages
#
# Demonstrates adding packages the NixOS-native way using
# environment.systemPackages inside nixosConfig.modules, instead of
# the flake-parts `dependencies` option.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosNginxSyspackages = {
            mainService = "nginx";
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
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
                    environment.systemPackages = with pkgs; [
                      curl
                      jq
                      htop
                    ];
                  }
                )
              ];
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./nginx-syspackages-cst.yaml
              ];
            };
          };
        };
      };
  };
}
