{ lib, ... }:
{
  options.oci.container.healthcheck = {
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
      description = "Health check command (CMD form). Set by service adapters or manually.";
    };

    interval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Seconds between health checks.";
    };

    timeout = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Seconds to wait for a single check.";
    };

    startPeriod = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Grace period (seconds) before first check.";
    };

    retries = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Consecutive failures before unhealthy.";
    };
  };
}
