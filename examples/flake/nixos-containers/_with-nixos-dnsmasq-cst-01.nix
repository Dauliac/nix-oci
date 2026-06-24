# Example: NixOS dnsmasq container with CST
#
# dnsmasq already runs in foreground in NixOS (--keep-in-foreground).
# Demonstrates a DNS/DHCP service container with diagnostic tools.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosDnsmasqCst = {
            mainService = "dnsmasq";
            isRoot = true;
            nixosConfig.modules = [
              (
                { pkgs, ... }:
                {
                  services.dnsmasq = {
                    enable = true;
                    settings = {
                      listen-address = "0.0.0.0";
                      port = 5353;
                      no-resolv = true;
                      server = [
                        "8.8.8.8"
                        "1.1.1.1"
                      ];
                    };
                  };
                  environment.systemPackages = with pkgs; [
                    dig
                  ];
                }
              )
            ];
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./dnsmasq-cst.yaml
              ];
            };
          };
        };
      };
  };
}
