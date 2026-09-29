# BDD test specs for the PostgreSQL service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `PostgreSQL container serves queries` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# Uses `stateDirectories` from the section-1 infra
# (nix/modules/oci/testing/test-vm.nix) to back
# `/var/lib/postgresql` and `/run/postgresql` with per-spec tmpfs on
# the VM host  -  this unblocks the container that would otherwise
# crash-loop because those paths are read-only in the Nix store.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-postgresql = {
        deploy-psql-select-one-returns-one = {
          given = "a PostgreSQL container with mainService = postgresql and writable tmpfs for /var/lib/postgresql";
          "when" = "psql -h localhost -U postgres -c 'SELECT 1' runs from the VM host";
          "then" = "the query returns 1";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          stateDirectories = [
            "/var/lib/postgresql"
            "/run/postgresql"
          ];
          container = {
            isRoot = true;
            ports = [ "5432:5432" ];
            nixosConfig = {
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
                        port = 5432;
                      };
                      # trust for local tests; the VM is hermetic
                      authentication = ''
                        local all all trust
                        host  all all 0.0.0.0/0 trust
                      '';
                    };
                  }
                )
              ];
            };
          };
          # psql needs the query string as a SINGLE argv, but the
          # `succeeds.args` helper shlex-splits on whitespace which
          # would turn "SELECT 1" into two args. Use the raw runtime
          # escape hatch to preserve quoting.
          assertions.runtime = ''
            import subprocess
            _out = subprocess.check_output([
                "${pkgs.postgresql_16}/bin/psql",
                "-h", "127.0.0.1",
                "-p", "5432",
                "-U", "postgres",
                "-tAc", "SELECT 1",
            ], timeout=30).decode("utf-8").strip()
            assert _out == "1", f"Expected SELECT 1 => 1, got: {_out!r}"
          '';
        };
      };
    };
}
