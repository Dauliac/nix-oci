# Per-container: OCI StopSignal configuration.
#
# Defines the signal sent to the container process for graceful shutdown.
# For NixOS containers, service adapters auto-derive this (e.g., nginx
# uses SIGQUIT for graceful worker shutdown, PostgreSQL uses SIGINT).
{ lib, ... }:
{
  options.stopSignal = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Signal to send for graceful container shutdown (e.g., "SIGQUIT", "SIGINT").
      When null, the container runtime default (SIGTERM) is used.

      For NixOS containers, service adapters auto-derive this from the
      systemd KillSignal or per-service knowledge.
    '';
    example = "SIGQUIT";
  };
}
