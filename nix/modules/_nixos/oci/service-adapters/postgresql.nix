# PostgreSQL: auto-derive healthcheck + stop signal from NixOS module config.
#
# Uses pg_isready from the configured postgresql package, targeting the
# configured port. No foreground adapter needed -- NixOS postgresql
# already runs in the foreground for containers (Type=notify).
#
# StopSignal: SIGINT for fast shutdown (rollback active transactions, clean exit).
# SIGQUIT would do "smart shutdown" (wait for clients to disconnect) which can
# hang in containers. SIGINT is the recommended signal for container PostgreSQL.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
  pgCfg = config.services.postgresql;
  port = toString (pgCfg.settings.port or 5432);
in
{
  config = lib.mkIf (cfg.mainService == "postgresql") {
    oci.container._output.detectedPorts = [ (pgCfg.settings.port or 5432) ];
    oci.container.healthcheck.command = lib.mkDefault [
      "${pgCfg.package}/bin/pg_isready"
      "-h"
      "localhost"
      "-p"
      port
    ];
    # SIGINT: fast shutdown -- rollback active transactions and exit cleanly.
    oci.container.stopSignal = lib.mkDefault "SIGINT";
  };
}
