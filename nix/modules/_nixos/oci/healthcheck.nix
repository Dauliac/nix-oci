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

  # Minimal /bin/sh for healthcheck execution.
  # Podman runs --health-cmd via "sh -c <cmd>", so /bin/sh must exist.
  # This creates a tiny derivation with /bin/sh → bash, avoiding pulling
  # in the full bashInteractive package.
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
