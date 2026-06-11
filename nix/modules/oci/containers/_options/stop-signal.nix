# Per-container: OCI StopSignal configuration.
#
# Defines the signal sent to the container process for graceful shutdown.
# For NixOS containers, service adapters auto-derive this (e.g., nginx
# uses SIGQUIT for graceful worker shutdown, PostgreSQL uses SIGINT).
{
  lib,
  pkgs,
  ...
}:
let
  example = "SIGQUIT";
in
{
  options.stopSignal = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    defaultText = lib.literalMD ''
      Auto-derived (strongest to weakest):
      1. service adapter signal (e.g. `SIGQUIT` for nginx, `SIGINT` for PostgreSQL)
      2. systemd `KillSignal`
      3. container runtime default (`SIGTERM`)
    '';
    description = ''
      Signal to send for graceful container shutdown (e.g., "SIGQUIT", "SIGINT").
      When null, auto-derived for NixOS containers from the service adapter
      or systemd KillSignal. Falls back to the container runtime default (SIGTERM).
    '';
    inherit example;
  };

  config._tests.stop-signal = {
    level = "inspect";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      stopSignal = example;
    };
    assertions.imageConfig.StopSignal = "SIGQUIT";
  };
}
