# Healthcheck: options and _output for service-derived health checks.
#
# Service adapters (nginx, postgresql, redis, …) set
# oci.container.healthcheck.command via mkDefault so users can override.
# The _output.healthcheck attrset is consumed by mkSimpleOCI/mkNixOCI
# to produce the OCI Healthcheck config block.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.healthcheck;
  binSh = pkgs.runCommand "bin-sh" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.bashInteractive}/bin/bash $out/bin/sh
  '';
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

  config.assertions = lib.optionals (cfg.command != [ ]) [
    {
      assertion = cfg.interval > 0;
      message = ''
        nix-oci: healthcheck.interval must be > 0, got ${toString cfg.interval}.
        The interval defines seconds between health checks.
      '';
    }
    {
      assertion = cfg.timeout > 0;
      message = ''
        nix-oci: healthcheck.timeout must be > 0, got ${toString cfg.timeout}.
        The timeout defines how long to wait for a single check.
      '';
    }
    {
      assertion = cfg.retries >= 1;
      message = ''
        nix-oci: healthcheck.retries must be >= 1, got ${toString cfg.retries}.
        At least one retry is needed to detect failures.
      '';
    }
    {
      assertion = cfg.startPeriod >= 0;
      message = ''
        nix-oci: healthcheck.startPeriod must be >= 0, got ${toString cfg.startPeriod}.
      '';
    }
    {
      assertion = cfg.timeout < cfg.interval;
      message = ''
        nix-oci: healthcheck.timeout (${toString cfg.timeout}s) must be less than
        interval (${toString cfg.interval}s). A check that takes longer than the
        interval will overlap with the next check.
      '';
    }
  ];

  # When a healthcheck is configured, ensure /bin/sh exists so podman
  # can run --health-cmd via "sh -c". Added to adapterPackages so it
  # ends up in the rootFilesystem's buildEnv.
  config.oci.container._output.adapterPackages = lib.mkIf (cfg.command != [ ]) [ binSh ];

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
