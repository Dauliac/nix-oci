# Example: NixOS PostgreSQL container with auto-derived healthcheck + CST
#
# Demonstrates the healthcheck feature for PostgreSQL: the service
# adapter auto-derives `pg_isready -h localhost -p 5432` from the
# NixOS module config. CST verifies pg_isready is available.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          nixosPostgresHealthcheck = {
            nixosConfig = {
              enable = true;
              mainService = "postgresql";
              modules = [
                (
                  { pkgs, ... }:
                  {
                    services.postgresql = {
                      enable = true;
                      package = pkgs.postgresql_16;
                      enableTCPIP = true;
                      settings = {
                        listen_addresses = "*";
                      };
                      authentication = ''
                        local all all trust
                        host  all all 0.0.0.0/0 md5
                      '';
                    };
                  }
                )
              ];
            };
            isRoot = true;
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./postgres-healthcheck-cst.yaml
              ];
            };
          };
        };
      };
  };
}
