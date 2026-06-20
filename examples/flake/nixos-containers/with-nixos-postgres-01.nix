# Example: NixOS PostgreSQL container
#
# Shows a production-grade PostgreSQL server built via NixOS modules.
# Useful for local dev or test environments. NixOS handles:
# - Data directory setup (initdb)
# - User/database creation
# - pg_hba.conf (authentication)
# - systemd-based entrypoint
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosPostgres = {
            mainService = "postgresql";
            nixosConfig.modules = [
                (
                  { pkgs, ... }:
                  {
                    services.postgresql = {
                      enable = true;
                      package = pkgs.postgresql_16;
                      enableTCPIP = true;
                      settings = {
                        listen_addresses = "*";
                        max_connections = 100;
                        shared_buffers = "128MB";
                      };
                      authentication = ''
                        local all all trust
                        host  all all 0.0.0.0/0 md5
                      '';
                      initialScript = pkgs.writeText "init.sql" ''
                        CREATE DATABASE app;
                        CREATE USER app WITH PASSWORD 'app';
                        GRANT ALL PRIVILEGES ON DATABASE app TO app;
                      '';
                    };
                  }
                )
              ];
            isRoot = true;
            labels = {
              "org.opencontainers.image.title" = "postgres";
              "org.opencontainers.image.description" = "PostgreSQL 16 via NixOS modules";
            };
          };
        };
      };
  };
}
