# Example: PostgreSQL with extensions and production tuning
#
# Demonstrates building a production-grade PostgreSQL container using
# NixOS module evaluation. All extensions are compiled and linked at
# build time -- no runtime "CREATE EXTENSION" surprises.
#
# What this shows:
# - PostgreSQL package override with PostGIS and pg_stat_statements
# - Production-like tuning (shared_buffers, work_mem, etc.)
# - Initial database and user setup via initialScript
# - Extension preloading via shared_preload_libraries
{ ... }:
{
  config = {
    perSystem =
      { ... }:
      {
        config.oci.containers = {
          nixosPostgresExtensions = {
            mainService = "postgresql";
            nixosConfig.modules = [
                (
                  {
                    pkgs,
                    lib,
                    ...
                  }:
                  {
                    services.postgresql = {
                      enable = true;
                      package = pkgs.postgresql_16;

                      # Extensions are compiled and linked at build time via the
                      # NixOS `extensions` option -- no `withPackages` wrapper needed.
                      extensions = ps: [
                        ps.postgis
                        ps.pg_repack
                      ];
                      enableTCPIP = true;

                      settings = {
                        # Connection
                        listen_addresses = lib.mkDefault "*";
                        max_connections = 200;

                        # Memory tuning
                        shared_buffers = "256MB";
                        effective_cache_size = "768MB";
                        work_mem = "4MB";
                        maintenance_work_mem = "128MB";

                        # WAL
                        wal_buffers = "16MB";
                        min_wal_size = "1GB";
                        max_wal_size = "4GB";

                        # Query planner
                        random_page_cost = 1.1;
                        effective_io_concurrency = 200;

                        # Monitoring
                        shared_preload_libraries = "pg_stat_statements";
                        "pg_stat_statements.max" = 10000;
                        "pg_stat_statements.track" = "all";

                        # Logging
                        log_min_duration_statement = 1000;
                        log_checkpoints = true;
                        log_connections = true;
                        log_disconnections = true;
                        log_lock_waits = true;
                      };

                      authentication = ''
                        local all all trust
                        host  all all 0.0.0.0/0 md5
                        host  all all ::/0      md5
                      '';

                      # Create app database with extensions on first boot
                      initialScript = pkgs.writeText "pg-init.sql" ''
                        CREATE DATABASE app;
                        CREATE USER app_user WITH PASSWORD 'changeme';
                        GRANT ALL PRIVILEGES ON DATABASE app TO app_user;

                        \c app
                        CREATE EXTENSION IF NOT EXISTS postgis;
                        CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
                        CREATE EXTENSION IF NOT EXISTS pg_repack;
                      '';
                    };
                  }
                )
              ];
            isRoot = true;
            ports = [ "5432:5432" ];
            labels = {
              "org.opencontainers.image.title" = "postgres-with-extensions";
              "org.opencontainers.image.description" =
                "PostgreSQL 16 with PostGIS, pg_stat_statements, pg_repack";
            };
            test.containerStructureTest = {
              enabled = true;
              configs = [
                ./postgres-extensions-cst.yaml
              ];
            };
          };
        };
      };
  };
}
