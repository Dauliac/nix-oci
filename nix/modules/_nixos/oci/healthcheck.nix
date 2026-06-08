# Healthcheck: options and _output for service-derived health checks.
#
# Service adapters (nginx, postgresql, redis, …) set
# oci.container.healthcheck.command via mkDefault so users can override.
# The _output.healthcheck attrset is consumed by mkSimpleOCI/mkNixOCI
# to produce the OCI Healthcheck config block.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container.healthcheck;
in
{
  options.oci.container.healthcheck = {
    command = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
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

  options.oci.container._output.healthcheck = lib.mkOption {
    type = lib.types.nullOr lib.types.attrs;
    internal = true;
    readOnly = true;
    description = "Computed healthcheck for OCI config (null if no command set).";
    default =
      if cfg.command != [ ] then
        {
          inherit (cfg)
            command
            interval
            timeout
            startPeriod
            retries
            ;
        }
      else
        null;
  };
}
