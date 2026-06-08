# BIND/named: run in foreground
#
# NixOS bind uses Type=forking. The -f flag keeps named in the
# foreground, which is required for containers without an init system.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
in
{
  config.services.bind.extraOptions = lib.mkIf (cfg.mainService == "named") (lib.mkDefault "-f");
}
