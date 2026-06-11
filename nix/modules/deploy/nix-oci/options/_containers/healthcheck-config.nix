# Per-container: resolved healthcheck configuration.
#
# Extracts healthcheck from NixOS eval or raw config options.
# Consumed by run-services for sdnotify integration.
{
  config,
  lib,
  ...
}:
let
  nixosEval = config.nixosConfig.eval or null;
  useNixosEval = nixosEval != null;
  out = if useNixosEval then nixosEval.oci.container._output else null;
in
{
  options.hasHealthcheck = lib.mkOption {
    type = lib.types.bool;
    readOnly = true;
    description = "Whether the container image has a healthcheck configured.";
    default =
      if useNixosEval then (out.healthcheck or null) != null else config.healthcheck.command != [ ];
  };

  options.healthcheckConfig = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Healthcheck command.";
          };
          interval = lib.mkOption {
            type = lib.types.int;
            description = "Interval between checks in seconds.";
          };
          timeout = lib.mkOption {
            type = lib.types.int;
            description = "Timeout per check in seconds.";
          };
          startPeriod = lib.mkOption {
            type = lib.types.int;
            description = "Grace period before checks start in seconds.";
          };
          retries = lib.mkOption {
            type = lib.types.int;
            description = "Number of consecutive failures before unhealthy.";
          };
        };
      }
    );
    readOnly = true;
    internal = true;
    description = "Resolved healthcheck config (from eval or raw options).";
    default =
      let
        hc =
          if useNixosEval then
            out.healthcheck or null
          else if config.healthcheck.command != [ ] then
            {
              inherit (config.healthcheck)
                command
                interval
                timeout
                startPeriod
                retries
                ;
            }
          else
            null;
      in
      hc;
  };
}
