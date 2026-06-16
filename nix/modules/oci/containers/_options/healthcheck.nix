# Per-container: OCI healthcheck configuration.
#
# Defines the HEALTHCHECK that gets baked into the OCI image manifest.
# When deployed with Podman + --sdnotify=healthy, systemd waits for the
# healthcheck to pass before considering the container service "ready".
{
  lib,
  examplesDir,
  ...
}:
let
  exampleCommand = [
    "curl"
    "-f"
    "http://localhost:8080/health"
  ];
in
{
  options.healthcheck = {
    command = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      defaultText = lib.literalMD ''
        Auto-derived by service adapters when available:
        - **nginx**: `curl` stub\_status or `/health` endpoint
        - **caddy**: `curl` admin API (`localhost:2019`)
        - **PostgreSQL**: `pg_isready`
        - **Redis**: `redis-cli ping`
        - **BIND/dnsmasq**: `dig` DNS query
        - **Postfix**: `postfix status`
      '';
      description = ''
        Health check command (CMD form).
        When non-empty, baked into the OCI image as `Healthcheck.Test`.

        For NixOS-based containers, service adapters can auto-derive this
        from the NixOS module configuration (ports, endpoints, etc.).

        Example: `[ "curl" "-f" "http://localhost:8080/health" ]`

        Full container example:
        ```nix
        ${builtins.readFile (examplesDir + "/option-snippets/healthcheck.nix")}
        ```
      '';
      example = exampleCommand;
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds between health checks.";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds to wait for a single health check to complete.";
    };

    startPeriod = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Grace period (seconds) before the first health check runs after container start.";
    };

    retries = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Number of consecutive failures before the container is considered unhealthy.";
    };
  };
}
