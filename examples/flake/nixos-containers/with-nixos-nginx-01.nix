# Example: nginx container configured via NixOS modules
#
# The NixOS nginx module generates the config file, and the service's
# systemd unit is translated into a container entrypoint wrapper.
# Foreground mode (daemon off) is auto-injected by the nginx service adapter.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nginx-nixos = {
            mainService = "nginx";
            nixosConfig.modules = [
              (
                { ... }:
                {
                  services.nginx = {
                    enable = true;
                    virtualHosts."localhost" = {
                      root = "/var/www";
                      locations."/".extraConfig = ''
                        return 200 "Hello from nix-oci + NixOS modules!";
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
  };
}
