# Example: NixOS nginx with CIS compliance checking
#
# Uses a real daemon (nginx) with auto-derived healthcheck from the
# service adapter, then runs `trivy image --compliance docker-cis-1.6.0`
# to verify the image satisfies the CIS Docker Benchmark.
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          minimalistWithComplianceTrivy = {
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
            isRoot = true;
            compliance.trivy = {
              enabled = true;
            };
          };
        };
      };
  };
}
