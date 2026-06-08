# Per-container: OCI healthcheck configuration.
#
# Defines the HEALTHCHECK that gets baked into the OCI image manifest.
# When deployed with Podman + --sdnotify=healthy, systemd waits for the
# healthcheck to pass before considering the container service "ready".
{ lib, ... }:
{
  options.healthcheck = {
    command = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Health check command (CMD form).
        When non-empty, baked into the OCI image as `Healthcheck.Test`.

        For NixOS-based containers, service adapters can auto-derive this
        from the NixOS module configuration (ports, endpoints, etc.).

        Example: `[ "curl" "-f" "http://localhost:8080/health" ]`
      '';
      example = [
        "curl"
        "-f"
        "http://localhost:8080/health"
      ];
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
